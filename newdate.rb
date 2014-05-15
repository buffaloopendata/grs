require 'mongo/driver'
require 'date'
include Mongo


mdb=MongoClient.new('localhost').db('citydata')
readcoll=mdb['citysales']

readcoll.find().each do |record|
 sales=[]
 begin
   record['sales'].each do |sale|
    sale['deedate']=sale['deedate'].to_s.gsub('-','').to_i
    puts sale['deedate']
    sales.push sale
   end
 rescue
  puts 'bomb yo', record
  next
 end
 readcoll.update({'_id' =>record['_id']},
                  {'$set'=>
                    {'sales'=>sales}
                })
end
