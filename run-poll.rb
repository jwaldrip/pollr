STDOUT.sync = true
require 'bundler/setup'
require 'active_support/all'
Bundler.require :default
I18n.enforce_available_locales = false

class Pollr
  include Capybara::DSL

  LINK = Base64.decode64 'aHR0cDovL2VsZXZhdGVwaG90b2dyYXBoeS5jb20vYmxvZy8yMDEzLWVuZ2FnZW1lbnQtc2hvb3QtY29udGVzdC12b3RlLWZhdm9yaXRlLw=='

  class << self

    attr_accessor :polls

    def run
      new.take_poll
    end

    def target_name
      ENV['NAME'] || fail('missing a name to vote for')
    end

    def target_place
      ENV['PLACE'].to_i || fail('missing a target place')
    end

    def target_lead
      ENV['LEAD'].to_i || 100
    end

  end

  delegate :target_name, :target_place, :target_lead, :polls, :polls=, to: self
  self.polls = {}

  def take_poll
    visit LINK
    if place <= target_place && ahead_next_place_by >= target_lead
      sleep 5.seconds
      click_link 'View Results'
    else
      sleep 0.01 until choice_exists?(target_name)
      choose(target_name)
      all('.pds-vote a').find { |btn| btn.text == 'Vote' }.click
    end
    sleep 0.01 until update_polls!.present?
    display_results
  end

  private

  def display_results
    in_relation_ary    = target_place.upto(place - 1).map do |place|
      "behind #{name_in_place place} in #{place.ordinalize} place by #{behind_place_by place} votes"
    end.reverse
    in_relation_ary    = ["ahead of #{name_in_next_place} by #{ahead_next_place_by} votes"] unless in_relation_ary.present?
    in_relation_string = in_relation_ary.to_sentence(words_connector: ", \n  ", last_word_connector: "\n  and ", two_words_connector: "\n  and ")
    puts "#{name.green} have #{votes.to_s.green} votes at " + "#{place.ordinalize} place".blue,
         "  and are #{in_relation_string}",
         nil
  end

  # Helpers

  def initialize
    Capybara.register_driver :poltergeist do |app|
      options = {
        phantomjs_logger: '/dev/null'
      }
      Capybara::Poltergeist::Driver.new(app, options)
    end
    Capybara.current_driver = :poltergeist
    page.driver.add_headers 'Referer' => 'https://www.facebook.com/'
    clear_cookies!
  end

  def clear_cookies!
    page.driver.browser.reset
  end

  def choice_exists?(selector)
    !!all('.pds-answer-group').find { |div| div.text =~ /#{selector}/ }
  end

  def browser
    Capybara.current_session.driver.browser
  end

  # Readers

  def place
    polls.keys.find { |place| in_place(place)[:name] =~ /#{target_name}/ } || Float::INFINITY
  end

  def name
    name_in_place place
  end

  def name_in_place(place)
    in_place(place)[:name]
  end

  def votes
    votes_for_place place
  end

  def ahead_next_place_by
    votes - votes_for_place(place + 1)
  end

  def name_in_next_place
    name_in_place place + 1
  end

  def behind_place_by(place)
    votes_for_place(place) - votes
  end

  def votes_for_place(place)
    in_place(place)[:votes] || 0
  end

  # Scoreboard
  def in_place(place)
    polls[place] || {}
  end

  def update_polls!
    self.polls = all('div.pds-feedback-group').each_with_index.reduce({}) do |hash, (element, i)|
      place = i + 1
      hash.merge place => {
        name:  element.first('.pds-answer-text').text.sub(/\d+\.\s*/, ''),
        votes: element.first('.pds-feedback-votes').text.sub(/\(((\d,?)+).*/, '\\1').gsub(/,/, '').to_i
      }
    end
  rescue
    self.polls = {}
  end

end

Pollr.run while true
