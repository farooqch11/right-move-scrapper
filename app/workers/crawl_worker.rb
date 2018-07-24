require 'rubygems'
require 'selenium-webdriver'
require 'nokogiri'
require 'capybara'
require 'csv'

class CrawlWorker

  include Sidekiq::Worker
  sidekiq_options :retry => 5

  def perform(url,total_pages)

      begin
        Capybara.register_driver :chrome do |app|
          profile = Selenium::WebDriver::Chrome::Profile.new
          profile['permissions.default.image']       = 2
          profile['network.cookie.cookieBehavior']       = 2
          # profile['permissions.default.css']       = 2
          # profile['general.useragent.override'] = "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/418.9 (KHTML, like Gecko) Hana/1.1"
          proxy = Selenium::WebDriver::Proxy.new http: '83.149.70.159:13010', ssl: '83.149.70.159:13010'
          caps = Selenium::WebDriver::Remote::Capabilities.chrome(:proxy => proxy)
          options = Selenium::WebDriver::Chrome::Options.new(profile: profile)
          
          chrome_bin_path = ENV.fetch('GOOGLE_CHROME_SHIM', nil)
          options.binary = chrome_bin_path if chrome_bin_path # only use custom path on heroku
          # options.add_argument('--headless') # this may be optional \

          client = Selenium::WebDriver::Remote::Http::Default.new
          client.read_timeout = 150 # instead of the default 60
          client.open_timeout = 150 # instead of the default 60
          options.args << '--headless'
          options.args << '--no-sandbox'
          options.args << '--disable-gpu'
          options.args << '--disable-infobars'

          Capybara::Selenium::Driver.new(app,browser: :chrome, options: options, http_client: client,desired_capabilities: caps)
        end

        Capybara.javascript_driver = :chrome
        Capybara.configure do |config|
          # config.default_max_wait_time = 300 # seconds
          config.default_driver = :chrome
        end

        # Visit
        browser = Capybara.current_session
        driver = browser.driver.browser
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

          browser.visit url_to_visit

          # Link.create(url: url,page_number: i)

          main_page = Nokogiri::HTML(driver.page_source)

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

              begin
                browser.visit "https://www.rightmove.co.uk#{page_url}"
              rescue
                next
              end


              browser.click_link('Market Info')

              loop do
                sleep(2)
                if driver.execute_script('return document.readyState') == "complete"
                  break

                end
              end

              detail_page = Nokogiri::HTML(driver.page_source)

              title = detail_page.xpath('//h1').text.squish;
              asking_price = detail_page.xpath("//div[@class='property-header-bedroom-and-price ']/p[@id='propertyHeaderPrice']").text.squish;
              location = detail_page.xpath("//div[@class='property-header-bedroom-and-price ']/div[@class='left']/address[@class='pad-0 fs-16 grid-25']").text.squish;

              last_sold_price = detail_page.xpath("//tr[1]/td[2]").text.squish;
              upload_date = detail_page.xpath("//*[@id='firstListedDateValue']").text.squish;
              puts "#######################################"
              puts title, asking_price ,last_sold_price, location

              asking_price = asking_price.gsub('From', '')
              asking_price = asking_price.gsub('Offers in Region of', '')
              asking_price = asking_price.gsub('Guide Price', '')


              Property.create(title: title,location: location,asking_price: asking_price,last_sold_price: last_sold_price,upload_date:upload_date,url: page_url)

            rescue
              puts "retrying ss"
              raise
            end

          end
        end

      rescue Exception
        puts "retrying "
        raise

      end


  end


end
