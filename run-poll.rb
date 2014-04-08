require 'bundler/setup'
require "minitest/autorun"

Bundler.require :default

class RunPoll < MiniTest::Test
  include Capybara::DSL

  SECRET_LINK = 'aHR0cDovL2VsZXZhdGVwaG90b2dyYXBoeS5jb20vYmxvZy8yMDEzLWVuZ2FnZW1lbnQtc2hvb3QtY29udGVzdC12b3RlLWZhdm9yaXRlLw=='
  SECRET_SELECTOR = 'MTAxLiBLcmlzdGVuIEphY29icyAmIEphc29uIFdhbGRyaXA='

  def setup
    Capybara.register_driver :chrome do |app|
      Capybara::Selenium::Driver.new(app, :browser => :chrome)
    end
    Capybara.current_driver = ENV['CI'] ? :webkit : :chrome
    page.driver.header 'Referer', 'https://www.facebook.com/'
  end

  def test_poll
    visit link
    click_link('View Results')
    sleep 5
    original_votes = get_votes
    click_link('Return To Poll')
    sleep 5
    choose(selector)
    all('.pds-vote a').find { |btn| btn.text == 'Vote' }.click
    sleep 5
    assert_operator get_votes, :>, original_votes
  end

  private

  def link
    Base64.decode64 SECRET_LINK
  end

  def selector
    Base64.decode64 SECRET_SELECTOR
  end

  def get_votes
    all('div.pds-feedback-group').find { |div| div.text =~ /#{selector}/ }.first('.pds-feedback-votes').text.sub(/\((\d+).*/, '\\1').to_i
  end

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

end