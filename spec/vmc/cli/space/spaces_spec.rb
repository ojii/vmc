require 'spec_helper'
require 'stringio'

describe VMC::Space::Spaces do
  let(:global) { { :color => false } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:output) { StringIO.new }
  let!(:space_1) { FactoryGirl.build(:space, :name => "bb_second", :apps => FactoryGirl.build_list(:app, 2), :service_instances => [FactoryGirl.build(:service_instance)]) }
  let!(:space_2) { FactoryGirl.build(:space, :name => "aa_first", :apps => [FactoryGirl.build(:app)], :service_instances => FactoryGirl.build_list(:service_instance, 3), :domains => [FactoryGirl.build(:domain)]) }
  let!(:space_3) { FactoryGirl.build(:space, :name => "cc_last", :apps => FactoryGirl.build_list(:app, 2), :service_instances => FactoryGirl.build_list(:service_instance, 2), :domains => FactoryGirl.build_list(:domain, 2)) }
  let(:spaces) { [space_1, space_2, space_3]}
  let(:organization) { FactoryGirl.build(:organization, :spaces => spaces) }
  let(:client) { FactoryGirl.build(:client, :spaces => spaces, :current_organization => organization) }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  subject do
    with_output_to output do
      Mothership.new.invoke(:spaces, inputs, given, global)
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:spaces] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "List spaces in an organization" }
      it { expect(Mothership::Help.group(:spaces)).to include(subject) }
    end

    describe 'inputs' do
      subject { command.inputs }

      it "is not missing any descriptions" do
        subject.each do |_, attrs|
          expect(attrs[:description]).to be
          expect(attrs[:description].strip).to_not be_empty
        end
      end
    end

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([{ :type => :optional, :value => nil, :name => :organization }])
      end
    end
  end

  it 'should have the correct first two lines' do
    subject

    output.rewind
    expect(output.readline).to match /Getting spaces.*OK/
    expect(output.readline).to eq "\n"
  end

  context 'when there are no spaces' do
    let(:spaces) { [] }

    context 'and the full flag is given' do
      let(:inputs) { {:full => true} }

      it 'displays yaml-style output with all space details' do
        any_instance_of VMC::Space::Spaces do |spaces|
          dont_allow(spaces).invoke
        end
        subject
      end
    end

    context 'and the full flag is not given (default is false)' do
      it 'should show only the progress' do
        subject

        output.rewind
        expect(output.readline).to match /Getting spaces.*OK/
        expect(output).to be_eof
      end
    end
  end

  context 'when there are spaces' do
    context 'and the full flag is given' do
      let(:inputs) { {:full => true} }

      it 'displays yaml-style output with all space details' do
        any_instance_of VMC::Space::Spaces do |spaces|
          mock(spaces).invoke(:space, :space => space_2, :full => true).ordered
          mock(spaces).invoke(:space, :space => space_1, :full => true).ordered
          mock(spaces).invoke(:space, :space => space_3, :full => true).ordered
        end
        subject
      end
    end

    context 'and the full flag is not given (default is false)' do
      it 'displays tabular output with names, spaces and domains' do
        subject

        output.rewind
        output.readline
        output.readline

        expect(output.readline).to match /name\s+apps\s+services/
        spaces.sort_by(&:name).each do |space|
          expect(output.readline).to match /#{space.name}\s+#{name_list(space.apps)}\s+#{name_list(space.service_instances)}/
        end
        expect(output).to be_eof
      end
    end
  end
end
