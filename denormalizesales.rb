require 'mongo/driver'
require 'date'
include Mongo


mdb=MongoClient.new('localhost').db('citydata')
readcoll=mdb['citysales']
writecoll=mdb['cityindivsales']
readcoll.find().each do |record|
 begin
   record['sales'].each do |sale|
     sale['location']=record['location']
     sale['address']=record['address']
     sale['sbl']=record['sbl']
     writecoll.insert sale
   end
 rescue
  puts 'bomb yo', record
  next
 end
end
