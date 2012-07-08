require File.expand_path('spec_helper.rb', File.dirname(__FILE__))
require 'ioable'
__END__
describe IOable::Inputtable do
  it 'is a module' do
    IOable::Inputtable.should be_a_kind_of(Module)
  end

  describe '#bytes' do
    before do
      @input = stub('a input extended by Inputtable')
      @input.stub!(:read).twice.and_return { 0x01 }
      @input.stub!(:read).and_return { nil }

      @input.extend(IOable::Inputtable)
    end

    it "returns an Enumerator when no block given" do
      @input.each_byte.should be_a_kind_of(Enumerator)
    end

    it 'calls #read(1) until it returns nil when a block given' do
      @input.mock!(:read, 1).exactly(3).times
      @input.each_byte.should be_a_kind_of(Enumerator)
    end

    it "yields each byte from #read"

  end
end
