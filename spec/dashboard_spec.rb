require 'spec_helper'
require 'rack/test'
require 'split/dashboard'

describe Split::Dashboard do
  include Rack::Test::Methods

  def app
    @app ||= Split::Dashboard
  end

  before(:each) { Split.backend.clean }

  it "should respond to /" do
    get '/'
    last_response.should be_ok
  end

  it "should reset an experiment" do
    experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')

    red = Split::Alternative.new('red', 'link_color')
    blue = Split::Alternative.new('blue', 'link_color')
    red.increment_participation
    blue.increment_participation

    post '/reset/link_color'

    last_response.should be_redirect

    new_red_count = Split::Alternative.new('red', 'link_color').participant_count
    new_blue_count = Split::Alternative.new('blue', 'link_color').participant_count

    new_blue_count.should eql(0)
    new_red_count.should eql(0)
  end

  it "should delete an experiment" do
    experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
    delete '/link_color'
    last_response.should be_redirect
    Split::Experiment.find('link_color').should be_nil
  end

  it "should mark an alternative as the winner" do
    experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')
    experiment.winner.should be_nil

    post '/link_color', :alternative => 'red'

    last_response.should be_redirect
    experiment.winner.name.should eql('red')
  end

  it "should display the start date" do
    experiment_start_time = Time.parse('2011-07-07')
    Time.stub(:now => experiment_start_time)
    experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')

    get '/'

    last_response.body.should include('<small>2011-07-07</small>')
  end

  it "should handle experiments without a start date" do
    experiment_start_time = Time.parse('2011-07-07')
    Time.stub(:now => experiment_start_time)
    experiment = Split::Experiment.find_or_create('link_color', 'blue', 'red')

    Split.backend.stub(:start_time => nil)

    get '/'

    last_response.body.should include('<small>Unknown</small>')
  end
end