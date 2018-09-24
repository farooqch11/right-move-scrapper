class CrawlWorker

  include Sidekiq::Worker
  sidekiq_options :retry => 5
  # require 'selenium-webdriver'
  # require 'nokogiri'
  # require 'capybara'
  require 'rubygems'
  require 'capybara'
  require 'capybara/dsl'
  require 'capybara/poltergeist'

  def perform(url="https://www.rightmove.co.uk/property-for-sale/find.html?searchType=SALE&locationIdentifier=REGION%5E1498&insId=1&radius=0.0&minPrice=&maxPrice=&minBedrooms=&maxBedrooms=&displayPropertyType=&maxDaysSinceAdded=&_includeSSTC=on&sortByPriceDescending=&primaryDisplayPropertyType=&secondaryDisplayPropertyType=&oldDisplayPropertyType=&oldPrimaryDisplayPropertyType=&newHome=&auction=false",total_pages=1)

    begin
      # Capybara.register_driver :firefox do |app|
      #   require 'selenium/webdriver'
      #   # Selenium::WebDriver::Firefox.driver_path = '/usr/local/bin/geckodriver'
      #   profile = Selenium::WebDriver::Firefox::Profile.new
      #   profile['permissions.default.image']       = 2
      #   profile['network.proxy.type']       = 'manual'
      #   profile['general.useragent.override'] = "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/418.9 (KHTML, like Gecko) Hana/1.1"
      #   profile.proxy = Selenium::WebDriver::Proxy.new http: '37.48.118.90:13040', ssl: '37.48.118.90:13040'
      #   options = Selenium::WebDriver::Firefox::Options.new(profile: profile)
      #   caps = Selenium::WebDriver::Remote::Capabilities.firefox marionette: true
      #   client = Selenium::WebDriver::Remote::Http::Default.new
      #   client.timeout = 120
      #   options.args << '--headless'
      #   # options.args << '--no-sandbox'
      #   options.args << '--disable-infobars'
      #   # options.args << '--disable-gpu'
      #   Capybara::Selenium::Driver.new :firefox, options: options, desired_capabilities: caps ,http_client: client
      # end
      #
      # Capybara.javascript_driver = :firefox
      # Capybara.configure do |config|
      #   config.default_max_wait_time = 150 # seconds
      #   config.default_driver = :firefox
      # end



      Capybara.register_driver :poltergeist do |app|
        Capybara::Poltergeist::Driver.new app,
                                          phantomjs_options: [ '--ignore-ssl-errors=yes',
                                                               '--load-images=no',
                                                               '--proxy=zproxy.lum-superproxy.io:22225',
                                                              '--proxy-auth=lum-customer-hl_92887fb2-zone-static:7v9rn5y28wfs'
                                                              ],
                                          js_errors: false,
                                          inspector: false,
                                          timeout: 120
      end
      Capybara.default_driver = :poltergeist
      Capybara.javascript_driver = :poltergeist
      Capybara.default_max_wait_time = 120
      Capybara.ignore_hidden_elements = true
      Capybara.run_server = false


      # Visit
      browser = Capybara.current_session
      browser.driver.headers = { "User-Agent" => "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0 Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/42.0." }
      driver = browser.driver.browser
      # driver.basic_authorize('lum-customer-hl_92887fb2-zone-static','7v9rn5y28wfs')


      # driver.manage.timeouts.page_load = 120
      url_params = url
      (0..total_pages.to_i).each do |i|

        if i >0
          url_to_visit = url_params + "&index=#{i*24}&"
          puts url_to_visit
        else
          url_to_visit  = url_params
        end

        puts url_to_visit
        puts i
        driver.restart if defined?(driver.restart)
        browser.visit url_to_visit

        # Link.create(url: url,page_number: i)
        main_page = Nokogiri::HTML(driver.body)

        urls = main_page.xpath("//div[@class='propertyCard-section']/div[@class='propertyCard-details']/a[@class='propertyCard-link']/@href");


        urls.map(&:text).each_with_index do |page_url, index|
          # puts page_url

          begin

            if Property.find_by_url(page_url).present?
              next
            end

            puts page_url

            if page_url == ""
              next
            end

            browser.visit "https://www.rightmove.co.uk#{page_url}"

            browser.click_link('Market Info')

            loop do
              sleep(2)
              if driver.evaluate("document.readyState") == "complete"
                break
              end
            end

            detail_page = Nokogiri::HTML(driver.body)

            title = detail_page.xpath('//h1').text.squish;
            asking_price = detail_page.xpath("//div[@class='property-header-bedroom-and-price ']/p[@id='propertyHeaderPrice']").text.squish;
            location = detail_page.xpath("//div[@class='property-header-bedroom-and-price ']/div[@class='left']/address[@class='pad-0 fs-16 grid-25']").text.squish;

            last_sold_price = detail_page.xpath("//div[@id='soldHistoryBody']/table[@class='similar-nearby-sold-history-table']/tbody/tr[@class='bdr-b similar-nearby-sold-history-row-height'][1]/td[2]").text.squish;
            upload_date = detail_page.xpath("//*[@id='firstListedDateValue']").text.squish;
            puts "#######################################"
            puts title, asking_price ,last_sold_price, location
            if (asking_price.include? "shared") || (asking_price.include? "*") || !(last_sold_price.present?)
              puts "going nextttttttttt"
              puts asking_price
              puts last_sold_price
              next
            end


            # asking_price = asking_price.gsub('From', '')
            # asking_price = asking_price.gsub('Offers in Region of', '')
            # asking_price = asking_price.gsub('Guide Price', '')
            # asking_price = asking_price.gsub('Offers Over', '')
            # asking_price = asking_price.gsub('Fixed Price', '')
            # asking_price = asking_price.gsub('Offers in Excess', '')
            asking_price = asking_price.gsub(/\D/, "")
            last_sold_price = last_sold_price.gsub(/\D/, "")


            asking_price_int = asking_price.gsub('£', '')
            asking_price_int = asking_price_int.gsub(',', '')
            last_sold_price_int = last_sold_price.gsub('£', '')
            last_sold_price_int = last_sold_price_int.gsub(',', '')

            equity_percentage = (asking_price_int.to_f/last_sold_price_int.to_f)*100

            if equity_percentage > 105
              puts "going nextttttttttt percent"
              puts equity_percentage
              next
            end

            byebug


            Property.create(equity_percentage: equity_percentage,title: title,location: location,asking_price: asking_price,last_sold_price: last_sold_price,upload_date:upload_date,url: page_url)

          rescue => exception
            next
          end

        end
      end

    rescue => exception
      puts exception
      raise
    end


  end


end
