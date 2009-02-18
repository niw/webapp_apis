#!/usr/bin/env ruby

require "rubygems"
require "rexml/document"
require "net/https"

class Dopplr
  def initialize(token)
    @token = token
    @http = Net::HTTP.new("www.dopplr.com", 443)
    @http.use_ssl = true
    upgrade_token
  end

  def method_missing(method, *args)
    res = get(method.to_s, *args)
    doc = REXML::Document.new(res.body)
    yield(doc.root) if block_given?
    doc.root
  end

  private

  def get(path, *args)
    params = token_param
    args.each do |arg|
      case arg
      when Hash
        params = params.merge(arg.inject({}){|h,(k,v)| h[k.to_s] = v; h})
      when String
        path = path + "/" + arg
      end
    end
    res = @http.start do |http|
      req = Net::HTTP::Get.new("/api/" + path, params)
      http.request(req)
    end
    yield(res) if block_given?
    res
  end

  def token_param
    {"Authorization" => "AuthSub token=\"#{@token}\""}
  end

  def upgrade_token
    res = get("AuthSubSessionToken")
    if m = res.body.match(/Token=(.*)/)
      @token = m[1]
    end
  end
end

d = Dopplr.new(ARGV.shift)
d.trips_info(:traveller => ARGV.shift) do |xml|
  days = {}
  xml.each_element("/trips_info/trip") do |trip|
    city = trip.get_text("city/name").to_s
    start = Date.parse(trip.get_text("start").to_s)
    finish = Date.parse(trip.get_text("finish").to_s)
    d = (finish - start).to_i + 1
    days[start.year] = (days[start.year] || 0) + d
    puts "#{start.strftime("%Y-%m-%d")} to #{finish.strftime("%Y-%m-%d")} in #{city} for #{d} days"
  end
  days.keys.sort.each do |k|
    puts "In #{k}, you are #{days[k]} days are not in your home town (#{(days[k].to_f / 365 * 100).to_i} %)"
  end
end
