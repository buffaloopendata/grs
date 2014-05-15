require 'mongo/driver'
require 'date'
include Mongo


mdb=MongoClient.new('localhost').db('citydata')
readcoll=mdb['citysales']

readcoll.find().each do |record|
 sales=[]
 begin
   record['sales'].each do |sale|
    sale['deedate']=Date.strptime(sale['deedate'],'%m/%d/%Y').to_s
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
