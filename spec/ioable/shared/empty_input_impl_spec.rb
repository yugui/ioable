shared_examples_for 'empty input impl' do
  describe '#auto_close?' do
    it "should return false" do
      @io.auto_close?.should be_false
    end

    it "should ignore the value set" do
      @io.auto_close = true
      @io.auto_close?.should be_false
    end
  end

  describe '#close_on_exec?' do
    it "should return false" do
      @io.close_on_exec?.should be_false
    end

    it "should ignore the value set" do
      @io.close_on_exec = true
      @io.close_on_exec?.should be_false
    end
  end

  describe '#closed?' do
    it "should return false" do
      @io.closed?.should be_false
    end
  end

end

