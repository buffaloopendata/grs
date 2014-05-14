require "sinatra/reloader"
require 'json'
require 'spawnling'
require 'csv'
#require 'mongo'
require 'sinatra'
require 'logger'
require 'pp'
require 'mongo/driver'
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
  conn = MongoClient.new(:logger=>access_logger)
  set :mongo_connection, conn
  set :mongo_db, conn.db('citydata')
end

helpers do
  def geoWithin(boundary, collection='realproperty') 
    polygon=JSON.parse boundary
    geometry=polygon['geometry']
    settings.mongo_db[collection].find({"location"=>{'$geoWithin'=>{'$geometry'=>geometry}}})
  end

  def geoWithinSales(boundary, startDate, endDate, collection='citysales')
    polygon=JSON.parse boundary
    geometry=polygon['geometry']
    settings.mongo_db[collection].find({
       "location"=>{'$geoWithin'=>{'$geometry'=> geometry}},
       'sales'=>{'$elemMatch'=>{ 'deedate'=>{"$lt"=>20140101}}},
       'sales'=>{'$elemMatch'=>{ 'deedate'=>{"$gt"=>20120101}}}
      })
  end

  def geoWithinIndivSales(boundary, startDate, endDate, collection='cityindivsales')
    polygon=JSON.parse boundary
    geometry=polygon['geometry']
    settings.mongo_db[collection].find({
       "location"=>{'$geoWithin'=>{'$geometry'=> geometry}},
        'deedate'=>{"$lt"=>20140101},
        'deedate'=>{"$gt"=>20120101}
      })
  end
end 

get '/' do
  erb :index
end

post '/calculate/flipping' do
  
end

post '/sales?' do
  startdate=20120101
  enddate=20130101
  sales=geoWithinIndivSales(params[:boundary],startdate,enddate)
  sales.to_a.to_json
end


post '/records?' do
  records=geoWithin params[:boundary]
  records.to_a.to_json
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
end

post '/calculate/sqft/?' do
  results=geoWithin params[:boundary]
  area=params[:sqft]
  dollars=0
  sqft=0
  results.each do |row|
    dollars+=row['assessment'].to_i
   # sqft+=row['squareft'].to_i
    sqft+=row['frontage'].to_i*row['depth'].to_i
  end
  (dollars/sqft).to_s
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


