require './spec/spec_helper'

RSpec.describe 'MockTracer' do
  require './mocktracer/mocktracer'
  require './mocktracer/mockspan'
  require './mocktracer/mockspan_context'

  let(:op_name) { @op_name = 'some-op-name' }
  let(:mockspan) { @mockspan = instance_double('MockSpan') }

  before(:each) do
    @default_propagator = instance_spy('TextMapPropagator')
    @http_propagator = instance_spy('TextMapPropagator')
    allow(TextMapPropagator).to receive(:new) do |http_headers|
      if http_headers
        @http_propagator
      else
        @default_propagator
      end
    end
    @mocktracer = MockTracer.new
  end

  describe '#initialize' do
    it 'initializes finished spans' do
      expect(@mocktracer.finished_spans).to eq([])
    end

    it 'registers injectors' do
      expect(@mocktracer.injectors).to eq(text_map: @default_propagator, http_headers: @http_propagator)
    end

    it 'registers extractors' do
      expect(@mocktracer.extractors).to eq(text_map: @default_propagator, http_headers: @http_propagator)
    end
  end

  describe '#start_span' do
    before(:each) { op_name }

    it 'creates a new span' do
      expect(@mocktracer.start_span(@op_name)).to have_attributes(tracer: @mocktracer, operation_name: @op_name)
    end
  end

  describe '#inject' do
    before(:each) do
      @span_context = instance_double('SpanContext')
      @carrier = instance_double('TextMapPropagator')
    end

    context 'when injector with the format exists' do
      it 'injects the span context with the carrier' do
        @mocktracer.inject(@span_context, :http_headers, @carrier)
        expect(@http_propagator).to have_received(:inject).once.with(@span_context, @carrier)
        expect(@default_propagator).not_to have_received(:inject)
      end
    end

    context 'when injector with the format does not exist' do
      it 'raises error' do
        expect{ @mocktracer.inject(@span_context, :unknown_format, @carrier) }.to raise_error(NameError)
        expect(@http_propagator).not_to have_received(:inject)
        expect(@default_propagator).not_to have_received(:inject)
      end
    end
  end

  describe '#extract' do
    before(:each) do
      @carrier = instance_double('TextMapPropagator')
    end

    context 'when extractor with the format exists' do
      before(:each) do
        @mock_span_context = instance_double('SpanContext')
        allow(@http_propagator).to receive(:extract).and_return(@mock_span_context)
      end

      it 'extracts the span context with the carrier' do
        span_context = @mocktracer.extract(:http_headers, @carrier)
        expect(span_context).to eq(@mock_span_context)
        expect(@http_propagator).to have_received(:extract).once.with(@carrier, MockSpanContext)
        expect(@default_propagator).not_to have_received(:extract)
      end
    end

    context 'when extractor with the format does not exist' do
      it 'raises error' do
        expect{ @mocktracer.extract(:unknown_format, @carrier) }.to raise_error(NameError)
        expect(@http_propagator).not_to have_received(:extract)
        expect(@default_propagator).not_to have_received(:extract)
      end
    end
  end

  describe '#record_span' do
    before(:each) { mockspan }

    it 'add span to finished spans' do
      @mocktracer.record_span(@mockspan)
      expect(@mocktracer.finished_spans).to eq([@mockspan])
    end
  end

  describe '#reset' do
    before(:each) { mockspan }

    it 'clears finished spans' do
      @mocktracer.record_span(@mockspan)
      expect(@mocktracer.finished_spans).to eq([@mockspan])

      @mocktracer.reset
      expect(@mocktracer.finished_spans).to eq([])
    end
  end
end
