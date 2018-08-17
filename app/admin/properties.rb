ActiveAdmin.register Property do
  permit_params :complete,:letter_sent,:unfindable,:house_no,:street_name,:city,:post_code

  scope :all do |example|
    Property.all
  end
  scope :incomplete do |example|
    Property.where(complete: false,letter_sent: false,unfindable: false)
  end
  scope :complete do |example|
    Property.where(complete: true, letter_sent: false ,unfindable: false)
  end
  scope :letter_sent do |example|
    Property.where(letter_sent: true)
  end
  scope :unfindable do |example|
    Property.where(unfindable: true)
  end


  index do
    selectable_column
    id_column
    column :title
    column :asking_price
    column :last_sold_price
    column :url do |property|
      link_to property.full_url, property.full_url ,target: :_blank
    end

    column :upload_date
    column :created_at
    actions
  end
  action_item :start_job, only: :index do
    link_to "Start Job", start_job_admin_properties_path
  end

  collection_action :start_job, title: "Start Scrapingg"  do
    # Nothing here. We just want to render the form.

  end

  collection_action :start_worker, title: "worker", method: :post do
    CrawlWorker.perform_async(params[:data][:url], params[:data][:total_pages])
    redirect_to admin_dashboard_path
  end
end
