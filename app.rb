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
       'sales'=>{'$elemMatch'=>{ 'deedate'=>{"$lt"=>endDate}}},
       'sales'=>{'$elemMatch'=>{ 'deedate'=>{"$gt"=>startDate}}}
      })
  end

  def geoWithinIndivSales(boundary, startDate, endDate, collection='cityindivsales')
    polygon=JSON.parse boundary
    geometry=polygon['geometry']
    settings.mongo_db[collection].find({
       "$and"=>
         [{"location"=>{'$geoWithin'=>{'$geometry'=> geometry}}},
          {'deedate'=>{"$lt"=>endDate}},
          {'deedate'=>{"$gt"=>startDate}}
         ]
      })
  end
end 

get '/' do
  erb :index
end

post '/calculate/flipping' do
  startdate=20090101
  enddate=20130101
  properties=geoWithinSales(params[:boundary],startdate,enddate)
  selection=[]
  #find('sales'=> {'$elemMatch'=>{'deedtype'=> "T- Tax Sale"}}).each do |row|
  properties.each do |row|
    row['sales'].each.with_index do |sale, idx|
      if row['sales'][idx+1].nil?
        next
      end
      currentSaleDate=Date.strptime(sale['deedate'].to_s, '%Y%m%d')
      nextSaleDate=Date.strptime row['sales'][idx+1]['deedate'].to_s, '%Y%m%d'
      

      currentSalePrice=sale['saleprice'][1..-1].to_f
      nextSalePrice=row['sales'][idx+1]['saleprice'][1..-1].to_f
      

      if currentSalePrice*1.20<nextSalePrice and nextSaleDate-currentSaleDate<365
        selection.push(row)
      end
    end
  end
  selection.to_a.to_json
end

post '/sales?' do
  startdate=20120101
  enddate=20120130
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


