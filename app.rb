require 'json'
require 'spawnling'
require 'csv'
require 'mongo'
require 'sinatra'
require 'logger'
require 'pp'
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
#  content_type 'application/octet-stream'
  polygon=JSON.parse params[:boundary] 
  geometry=polygon['geometry']
  filename=geometry['coordinates'].join[0..180].gsub! /[.-]/,''
  File.open("./datasets/#{filename}.part", "w") {}

  Spawnling.new do
    results=settings.mongo_db['realproperty'].find({"location"=>{'$geoWithin'=>{'$geometry'=>geometry}}}).to_a
    CSV.open("./datasets/#{filename}.part", 'w') do |writer|
      writer << results[0].keys
      results.each do |record|
        writer << record.values
      end
    end
    File.rename("./datasets/#{filename}.part", "./datasets/#{filename}.csv")
  end

  "Processing your request right over <a href='/dataset/#{filename}'>Here</a>"
  redirect to "/dataset/#{filename}"
#  attachment('records.csv')
end

get '/documents/?' do
  content_type :json
  settings.mongo_db['realproperty'].find.to_a[0].to_json
end

post '/test?' do
  content_type :json
  polygon=JSON.parse params[:boundary] 
  geometry=polygon['geometry']
  pp settings.mongo_db['realproperty'].find({"location"=>{'$geoWithin'=>{'$geometry'=>geometry}}}).explain
end

get '/dataset/:id' do |id|
  if File.exists? "./datasets/#{id}.csv"
    'existance!'
     content_type 'application/octet-stream'
     attachment "./datasets/#{id}.csv"  
  elsif File.exists? "./datasets/#{id}.part"
    'still processing refresh the page in a few seconds...'
  else 
    'rerun your selection'
  end 
end


post '/test/csv?' do
#  content_type 'application/octet-stream'
  polygon=JSON.parse params[:boundary] 
  geometry=polygon['geometry']
  filename=geometry['coordinates'].join[0..180].gsub! /[.-]/,''
  File.open("./datasets/#{filename}.part", "w") {}

  Spawnling.new do
    results=settings.mongo_db['realproperty'].find({"location"=>{'$geoWithin'=>{'$geometry'=>geometry}}}).to_a
    CSV.open("./datasets/#{filename}.part", 'w') do |writer|
      writer << results[0].keys
      results.each do |record|
        writer << record.values
      end
    end
    File.rename("./datasets/#{filename}.part", "./datasets/#{filename}.csv")
  end

  "Processing your request right over <a href='/dataset/#{filename}'>Here</a>"
  redirect to "/dataset/#{filename}"
#  attachment('records.csv')
end
