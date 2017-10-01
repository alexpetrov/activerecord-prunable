# frozen_string_literal: true

require 'spec_helper'

describe ActiveRecord::Prunable do
  subject { SomeMixin }

  before do
    allow(subject).to receive(:logger).and_return(Logger)
  end

  describe '.includes' do
    it 'has array with all prunable models' do
      expect(described_class.includes).to contain_exactly(SomeMixin, AnotherMixin)
    end
  end

  describe '.prune_method' do
    context 'incorrect prune method' do
      it 'returns false' do
        expect(subject.prune_method(123)).to be false
        expect(subject.prune_method(:something)).to be false
      end

      it "doesn't change @@prune_method variable" do
        expect { subject.prune_method(:incorrect) }
          .not_to(change { subject.class_variable_defined?(:@@prune_method) })
      end
    end

    context 'correct prune method' do
      it 'returns method name' do
        expect(subject.prune_method(:destroy)).to eq(:destroy)
        expect(subject.prune_method(:delete)).to eq(:delete)
      end

      it 'sets @@prune_method_variable' do
        subject.prune_method(:destroy)

        expect { subject.prune_method(:delete) }
          .to change { subject.class_variable_get(:@@prune_method) }
          .from(:destroy)
          .to(:delete)
      end
    end
  end

  describe '.prune!' do
    let(:correct_scope) { ->() { ActiveRecord::Relation.new(FakeActiveRecord, FakeActiveRecord.arel_table) } }
    let(:incorrect_scope) { ->() { 123 } }
    let(:prunable) { double(is_a?: true, destroy_all: [], delete_all: 0) }

    context 'scope is empty' do
      it 'raises error when scope result is not ActiveRecord::Relation' do
        expect(subject.respond_to?(:prunable)).to eq(false)
        expect_any_instance_of(ActiveRecord::Relation).not_to receive(:present?)
        expect_any_instance_of(ActiveRecord::Relation).not_to receive(:destroy_all)
        expect { subject.prune! }.not_to raise_error
      end
    end

    context 'correct scope' do
      before do
        subject.scope(:prunable, correct_scope)
        allow(subject).to receive(:defined?).and_return(false)
      end

      let(:prune_result) { 0 }

      it 'returns result of .prune_by_method' do
        allow(subject).to receive(:prune_by_method).and_return(prune_result)
        allow_any_instance_of(ActiveRecord::Relation).to receive(:present?).and_return(false)
        expect(subject).to receive(:prune_by_method)
        expect(subject.prune!).to eq(prune_result)
      end

      context 'prune method has been set' do
        before do
          allow(subject).to receive(:prunable).and_return(prunable)
        end

        it 'removes records by destroy_all method' do
          subject.prune_method(:destroy)
          expect(prunable).to receive(:destroy_all)
          subject.prune!
        end

        it 'removes records by delete_all' do
          subject.prune_method(:delete)
          expect(prunable).to receive(:delete_all)
          subject.prune!
        end
      end

      context 'with params' do
        before do
          allow(subject).to receive(:prunable).and_return(prunable)
        end

        it 'calls scope with params' do
          expect(subject).to receive(:prunable)
            .with(:foo, :bar)
            .and_return(:result)

          subject.prune!(:foo, :bar)
        end
      end
    end

    context 'incorrect scope' do
      it 'returns false' do
        subject.scope(:prunable, incorrect_scope)
        expect(subject.prune!).to be false
      end
    end
  end
end
