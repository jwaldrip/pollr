require 'bundler/setup'
require 'active_support/all'
Bundler.require :default

class Pollr
  include Capybara::DSL

  SECRET_LINK     = 'aHR0cDovL2VsZXZhdGVwaG90b2dyYXBoeS5jb20vYmxvZy8yMDEzLWVuZ2FnZW1lbnQtc2hvb3QtY29udGVzdC12b3RlLWZhdm9yaXRlLw=='
  SECRET_SELECTOR = 'MTAxLiBLcmlzdGVuIEphY29icyAmIEphc29uIFdhbGRyaXA='

  class << self

    attr_accessor :matrix

    def run
      new.take_poll
    end

  end

  delegate :matrix, :matrix=, to: self
  self.matrix = {}

  def take_poll
    visit link
    sleep 0.01 until choice_exists?(selector)
    choose(selector)
    all('.pds-vote a').find { |btn| btn.text == 'Vote' }.click
    sleep 0.01 until update_matrix!.present?
    bcts = 1.upto(place - 1).map do |place|
      "  behind place #{place} by #{behind_place_by place}"
    end
    bcts = ["  ahead by #{ahead_next_place_by}"] unless bcts.present?
    puts "votes: #{votes}, place: #{place}\n", *bcts
  end

  private

  def initialize
    sleep 30.seconds if place == 1 && ahead_next_place_by > 200
    Capybara.register_driver :chrome do |app|
      Capybara::Selenium::Driver.new(app, :browser => :chrome)
    end
    if ENV['CI']
      Capybara.current_driver = :webkit
      page.driver.header 'Referer', 'https://www.facebook.com/'
    else
      Capybara.current_driver = :chrome
    end
    clear_cookies!
  end

  def clear_cookies!
    if browser.respond_to?(:clear_cookies)
      # Rack::MockSession
      browser.clear_cookies
    elsif browser.respond_to?(:manage) && browser.manage.respond_to?(:delete_all_cookies)
      # Selenium::WebDriver
      browser.manage.delete_all_cookies
    else
      raise "Don't know how to clear cookies. Weird driver?"
    end
  end

  def browser
    Capybara.current_session.driver.browser
  end

  def link
    Base64.decode64 SECRET_LINK
  end

  def selector
    Base64.decode64 SECRET_SELECTOR
  end

  def place
    matrix.find { |k, v| v.text =~ /#{selector}/ }.first
  rescue
    9999
  end

  def votes
    votes_for_place place
  end

  def ahead_next_place_by
    votes - votes_for_place(place + 1)
  end

  def behind_place_by(place)
    votes_for_place(place) - votes
  end

  def votes_for_place(place)
    matrix[place].first('.pds-feedback-votes').text.sub(/\(((\d,?)+).*/, '\\1').gsub(/,/, '').to_i
  rescue
    0
  end

  def update_matrix!
    self.matrix = Hash[all('div.pds-feedback-group').each_with_index.map { |f, i| [(i + 1), f ] }]
  rescue
    self.matrix = {}
  end

  def choice_exists?(selector)
    !!all('.pds-answer-group').find { |div| div.text =~ /#{selector}/ }
  end

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

end

Pollr.run while true
