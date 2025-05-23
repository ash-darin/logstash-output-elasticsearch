require "logstash/outputs/elasticsearch"
require_relative "../../../spec/es_spec_helper"

describe "whitelisting error types in expected behavior" do
  let(:template) { '{"template" : "not important, will be updated by :index"}' }
  let(:event1) { LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z") }
  let(:settings) { {"manage_template" => true, "index" => "logstash-2014.11.17", "template_overwrite" => true, "hosts" => get_host_port() } }

  subject { LogStash::Outputs::ElasticSearch.new(settings) }

  before :each do
    allow(subject.logger).to receive(:warn)
    allow(subject).to receive(:maximum_seen_major_version).and_return(0)
    allow(subject).to receive(:alive_urls_count).and_return(1)
    allow(subject).to receive(:finish_register)

    subject.register

    allow(subject.client).to receive(:get_xpack_info)
    allow(subject.client).to receive(:bulk).and_return(
      {
        "errors" => true,
        "items" => [{
          "create" => {
            "status" => 409, 
            "error" => {
              "type" => "version_conflict_engine_exception",
              "reason" => "[shard] document already exists"
            }
          }
        }]
      })

    subject.multi_receive([event1])
  end

  after :each do
    subject.close
  end

  describe "when failure logging is enabled for everything" do
    it "should log a failure on the action" do
      expect(subject.logger).to have_received(:warn).with("Failed action", anything)
    end
  end

  describe "when failure logging is disabled for document exists error" do
    let(:settings) { super().merge("silence_errors_in_log" => ["version_conflict_engine_exception"]) }

    it "should log a failure on the action" do
      expect(subject.logger).not_to have_received(:warn).with("Failed action", anything)
    end
  end

end
