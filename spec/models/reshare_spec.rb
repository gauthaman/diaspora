require 'spec_helper'

describe Reshare do
  include ActionView::Helpers::UrlHelper
  include Rails.application.routes.url_helpers
  def controller
    mock()
  end


  it 'has a valid Factory' do
    Factory(:reshare).should be_valid
  end

  it 'requires root' do
    reshare = Factory.build(:reshare, :root => nil)
    reshare.should_not be_valid
  end

  it 'require public root' do
    Factory.build(:reshare, :root => Factory.build(:status_message, :public => false)).should_not be_valid
  end

  it 'forces public' do
    Factory(:reshare, :public => false).public.should be_true
  end

  describe "#receive" do
    before do
      @reshare = Factory.create(:reshare, :root => Factory(:status_message, :author => bob.person, :public => true))
      @root = @reshare.root
      @reshare.receive(@root.author.owner, @reshare.author)
    end

    it 'increments the reshare count' do
      @root.resharers.count.should == 1
    end

    it 'adds the resharer to the re-sharers of the post' do
      @root.resharers.should include(@reshare.author)
    end
  end

  describe "XML" do
    before do
      @reshare = Factory(:reshare)
      @xml = @reshare.to_xml.to_s
      pp @xml
    end

    context 'serialization' do
      it 'serializes root_diaspora_id' do
        @xml.should include("root_diaspora_id")  
      end

      it 'serializes root_guid' do
        @xml.should include("root_guid")  
      end
    end

    context 'marshalling' do
      context 'local' do
        before do
          @original_author = @reshare.root.author.dup
          @root_object = @reshare.root.dup
        end

        it 'fetches the root post from root_guid' do
          Reshare.from_xml(@xml).root.should == @root_object
        end

        it 'fetches the root author from root_diaspora_id' do
          Reshare.from_xml(@xml).root.author.should == @original_author
        end
      end

      context 'remote' do
        before do
          @original_profile = @reshare.root.author.profile
          @original_author = @reshare.root.author.delete
          @root_object = @reshare.root.delete
        end

        it 'fetches the root post from root_guid' do
          @original_profile.save!
          pp @original_profile
          @original_author.save!
          pp @original_author
          Faraday.should_receive(:get).with(@original_author.url + public_post_path(:guid => @reshare.guid)).and_return(@root_object.to_diaspora_xml)
          Reshare.from_xml(@xml).root.should == @root_object
        end

        it 'fetches the root author from root_diaspora_id' do
          person = Factory.build(:person)
          wf_prof_mock = mock
          wf_prof_mock.should_receive(:fetch).and_return(person)
          Webfinger.should_receive(:new).and_return(wf_prof_mock)
          Reshare.from_xml(@xml)
        end
      end
    end
  end
end
