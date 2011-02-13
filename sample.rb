#encoding:utf-8
$KCODE="u" if RUBY_VERSION <= "1.9"
require './kanachu.rb'

c = KanachuCrawler.new

c.search("湘南台駅西口",:hour=>12,:day=>:saturday,:new_diagram=>true).each do |b|
  puts "#{b[:day]} #{b[:hour]}:#{b[:minute]} [#{b[:series]}]#{b[:from]}→#{b[:for]} #{b[:notes].length>0?"（#{b[:notes].join('・')}）":""}"
end
