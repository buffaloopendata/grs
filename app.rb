require 'json'
require 'csv'
require 'mongo'
require 'sinatra'
require 'logger'
include Mongo

enable :logging
enable :raise_errors 
enable :dump_errors
enable :show_execptions

  ::Logger.class_eval { alias :write :'<<' }
  access_log = ::File.join(::File.dirname(::File.expand_path(__FILE__)),'','log','access.log')
  access_logger = ::Logger.new(access_log)
  error_logger = ::File.new(::File.join(::File.dirname(::File.expand_path(__FILE__)),'','log','error.log'),"a+")
  error_logger.sync = true
 
 
  before {
    env["rack.errors"] =  error_logger
  }

configure do
  use ::Rack::CommonLogger, access_logger
  conn = MongoClient.new("localhost", 27017)
  set :mongo_connection, conn
  set :mongo_db, conn.db('citydata')
end

post '/records?' do
  content_type :json
  polygon=JSON.parse params[:boundary] 
  geometry=polygon['geometry']
  settings.mongo_db['realproperty'].find({"location"=>{'$geoWithin'=>{'$geometry'=>geometry}}}).to_a.to_json
end

post '/records/csv?' do
  content_type :text
  polygon=JSON.parse params[:boundary] 
  geometry=polygon['geometry']
  results=settings.mongo_db['realproperty'].find({"location"=>{'$geoWithin'=>{'$geometry'=>geometry}}}).to_a
  #csvresults = results.each_with_object([]) { |i,mem| mem << i.to_a}.flatten.to_csv
  header=CSV::Row.new(results[0].keys,results[0].keys,true)
  t = CSV::Table.new([header])
  results.each do |record|
   t << record.values
  end
  t
end

get '/documents/?' do
  content_type :json
  settings.mongo_db['realproperty'].find.to_a[0].to_json
end

