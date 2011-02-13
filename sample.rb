#encoding:utf-8
$KCODE="u" if RUBY_VERSION <= "1.9"
require './kanachu.rb'

c = KanachuCrawler.new

c.search(:from=>"湘南台駅西口",:hour=>12,:day=>:saturday,:new_diagram=>true).sort{|a,b|a[:minute]<=>b[:minute]}.each do |b|
  puts "#{b[:day]} #{format("%02d",b[:hour])}:#{format("%02d",b[:minute])} [#{b[:series]}]#{b[:from]}→#{b[:for]} #{b[:notes].length>0?"（#{b[:notes].join('・')}）":""}"
end
