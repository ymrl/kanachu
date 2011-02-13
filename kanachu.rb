#!/usr/bin/ruby
#coding:utf-8
$KCODE="u" if RUBY_VERSION < "1.9"
require 'rubygems'
require 'mechanize'
require 'kconv'


class KanachuCrawler

  def initialize
    @agent =  Mechanize.new
    @encode = nil

    # 受信するテキストをすべてUTF-8にする
    @agent.post_connect_hooks << Proc.new do |prm|
      if prm[:response]["Content-Type"] =~ /^text\/.*$/
        @encode = Kconv.guess(prm[:response_body])
        prm[:response_body] = Kconv.kconv(prm[:response_body],Kconv::UTF8,Kconv::AUTO)
        prm[:response]["content-Type"] = "text/html; charset=utf-8"
        prm[:response_body].gsub!(/<meta[^>]*>/i) do |m|
          m.sub(/S(?:hift)?[-|_]JIS|EUC[-_]JP|Windows-31J/i,"UTF-8")
        end
      end
    end

    # 送信するテキストをUTF-8からもとの文字コードに戻す
    @agent.pre_connect_hooks << Proc.new do |prm|
      if @encode
        np = []
        prm[:params].each do |m|
          np.push URI.encode(Kconv::kconv(URI.decode(m),@encode))
        end
        prm[:params] = np
      end
    end

    @busstop_list = nil

  end

  def search query,subquery={}
    @agent.get 'http://dia.kanachu.jp/bus/viewtop'
    opt = {:hour=>:all,:day=>:all}
    if query.class == String 
      opt.merge!(subquery)
      return _simple_search(query,opt)
    else
      return _simple_search(query[:from],query.merge(subquery))
    end
  end

  def _simple_search str,opt
    @agent.page.form('fmTime').field('keyword').value = str
    @agent.page.form('fmTime').submit
    return _each_busstops @agent,opt
  end

  def _each_busstops agent,opt
    busstops = agent.page.form('fmTime').field('busstop').options
    data = []
    busstops.each do |o|
      agent.page.form('fmTime').field.value = o
      agent.transact do |a|
        a.page.form('fmTime').submit
        if opt[:new_diagram]
          a.page.link_with(:text=>/apply=\d{4}\/\d{2}\/\d{2}/)
        end
        data.concat(_get_data a,opt)
      end
    end
    return data
  end

  def _get_data agent,opt
    data = []
    agent.page.links_with(:href=>/^javascript:wopen\('(.*)'\)$/).each do |l|
      if opt[:day] != :all
        if opt[:day] == :weekday
          next if l.text !~ /平日/
        elsif opt[:day] == :saturday
          next if l.text !~ /土曜/
        elsif opt[:day] == :holiday
          next if l.text !~ /休日/
        end
      end
      path = l.href.match(/^javascript:wopen\('(.*)'\)$/)[1]
      agent.get('http://dia.kanachu.jp'+path)
      busstop =
        agent.page.parser.xpath('html/body/table/tr/td')[1].text.gsub(/バス停時刻表/,'')
      table = agent.page.parser.xpath('html/body/table')[1].xpath('tr')
      dest = table[0].xpath('td')[1].text.gsub(/[ \s　]/,'').gsub(/行$/,'')
      series = table[1].xpath('td')[1].text.chop
      day = table[2].text.gsub(/[ \s　]/,'')
      n = table[-1].xpath('td')[-1].children
      notes = Hash.new
      (n.length/2).times do |r|
        if n[2*r].attributes['color']
          notes[n[2*r].attributes['color'].value] =
            n[2*r+1].text.gsub(/[ \s　]/,'').gsub(/^：/,'')
        end
      end
      body = table[3,table.length-4]
      body.each do |row|
        hour = row.xpath('td')[0].text.to_i
        next if opt[:hour] != :all and opt[:hour] != hour
        note = nil
        bs = nil
        if row.xpath('td/table/tr')[0]
          n = row.xpath('td/table/tr')[0].xpath('td')
          bs = row.xpath('td/table/tr')[1].xpath('td')
        else
          next
        end

        bs.length.times do |i|
          next if bs[i].text.gsub(/[ \s　]/,'') == ""
          min = bs[i].text.to_i
          note = Array.new
          if n[i*2] && n[i*2].text.gsub(/[ \s　]/,'') != ""
            note << notes[n[i*2].xpath('font')[0].attributes['color'].value]
          end
          if n[i*2+1] && n[i*2+1].text.gsub(/[ \s　]/,'') != ""
            note << notes[n[i*2+1].xpath('font')[0].attributes['color'].value]
          end
          if bs[i].search('font')[0]
            note << notes[bs[i].search('font')[0].attributes['color'].value]
          end
           data << { :hour => hour , :minute => min , :notes => note,
             :for => dest , :series => series, :day => day ,:from => busstop}
        end
      end
    end
    return data
  end
end
