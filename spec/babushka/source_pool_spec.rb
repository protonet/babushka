require 'spec_helper'
require 'source_support'
require 'source_pool_support'

describe SourcePool, '#source_for' do
  before {
    @source1 = Source.new nil, :name => 'source_1'
    @source1.stub!(:load!)
    @source2 = Source.new nil, :name => 'source_2'
    @source2.stub!(:load!)
    Base.sources.stub!(:current).and_return([@source1])
    Source.stub!(:present).and_return([@source2])
  }
  it "should find core sources" do
    Base.sources.source_for('source_1').should == @source1
  end
  it "should find cloned sources" do
    Base.sources.source_for('source_2').should == @source2
  end
end

describe Dep, '#dep_for, disregarding sources' do
  before {
    @dep = dep 'Base.sources.dep_for tests'
  }
  it "should work for strings" do
    Base.sources.dep_for('Base.sources.dep_for tests').should == @dep
  end
  it "should work for deps" do
    Base.sources.dep_for(@dep).should == @dep
  end
  it "should not find the dep with namespacing" do
    Base.sources.dep_for('namespaced:namespaced Base.sources.dep_for tests').should be_nil
  end
  context "with namespaced dep defined" do
    before {
      @source = Source.new(nil, :name => 'namespaced')
      Source.stub!(:present).and_return([@source])
      Base.sources.load_context :source => @source do
        @namespaced_dep = dep 'Base.sources.dep_for tests'
      end
    }
    it "should work with namespacing" do
      Base.sources.dep_for('namespaced:Base.sources.dep_for tests').should == @namespaced_dep
    end
  end
end

describe SourcePool, '#dep_for' do
  before {
    @source1 = Source.new nil, :name => 'source_1'
    @source1.stub!(:load!)
    @source2 = Source.new nil, :name => 'source_2'
    @source2.stub!(:load!)
    Base.sources.load_context :source => @source1 do
      @dep1 = dep 'dep 1'
      @dep2 = dep 'dep 2'
    end
    Base.sources.load_context :source => @source2 do
      @dep3 = dep 'dep 3'
      @dep4 = dep 'dep 4'
    end
    Base.sources.stub!(:current).and_return([@source1, @source2])
    Source.stub!(:present).and_return([@source1, @source2])
  }
  it "should look up the correct deps without namespacing" do
    Base.sources.dep_for('dep 1').should == @dep1
    Base.sources.dep_for('dep 4').should == @dep4
  end
  it "should find the dep when the namespace is correct" do
    Base.sources.dep_for('source_1:dep 1').should == @dep1
    Base.sources.dep_for('source_2:dep 4').should == @dep4
  end
  it "should not find the dep when the namespace is wrong" do
    Base.sources.dep_for('source_1:dep 3').should be_nil
    Base.sources.dep_for('source_2:dep 2').should be_nil
  end
end

describe SourcePool, '#dep_for core' do
  before {
    @core = Source.new nil, :name => 'core'
    @core.stub!(:load!)
    Base.sources.load_context :source => @core do
      @dep1 = dep 'dep 1'
      @dep2 = dep 'dep 2'
    end
    Base.sources.stub!(:current).and_return([@core])
  }
  it "should find the correct deps without namespacing" do
    Base.sources.dep_for('dep 1').should == @dep1
    Base.sources.dep_for('dep 4').should == @dep4
  end
  it "should find the dep when the namespace is correct" do
    Base.sources.dep_for('core:dep 1').should == @dep1
  end
  it "should not find the dep when the namespace is wrong" do
    Base.sources.dep_for('non_core:dep 1').should be_nil
  end
end

describe SourcePool, '#template_for' do
  before {
    mock_sources
  }
  context "without namespacing" do
    it "should find templates in the anonymous source" do
      Base.sources.template_for('anonymous_meta').should == @anonymous_meta
    end
    it "should find templates in the core source" do
      Base.sources.template_for('core_meta').should == @core_meta
    end
    it "should not find templates from non-default sources" do
      Base.sources.template_for('meta_1').should be_nil
      Base.sources.template_for('meta_3').should be_nil
    end
    context "with :from" do
      it "should find the template in the same source" do
        Base.sources.template_for('from_test', :from => @source1).should == @from1
        Base.sources.template_for('from_test', :from => @source2).should == @from2
      end
      context "when it doesn't exist in the :from source" do
        it "should find the template in the core source" do
          Base.sources.template_for('core_from', :from => @source1).should == @core_from
        end
        it "should not find the template in other sources" do
          Base.sources.template_for('from_test_2', :from => @source1).should be_nil
          Base.sources.template_for('from_test_2', :from => @source2).should_not be_nil
        end
      end
    end
  end
  context "with namespacing" do
    it "should find the dep when the namespace is correct" do
      Base.sources.template_for('source_1:meta_1').should == @meta1
      Base.sources.template_for('source_2:meta_4').should == @meta4
    end
    it "should not find the dep when the namespace is wrong" do
      Base.sources.template_for('source_1:').should be_nil
      Base.sources.template_for('source_2:meta 2').should be_nil
    end
  end
  after {
    Base.sources.anonymous.templates.clear!
    Base.sources.core.templates.clear!
  }
end

describe SourcePool, '#load_context' do
  context "without a template" do
    before {
      Dep.should_receive(:new).with('load_context', Base.sources.anonymous, [], {}, nil)
    }
    it "should pass the correct options" do
      dep 'load_context'
    end
  end
  context "with a template" do
    let(:source) { Source.new(nil) }
    let!(:template) {
      Base.sources.load_context :source => source do
        meta 'load_context_template'
      end
    }
    let!(:the_dep) {
      Base.sources.load_context :source => source do
        dep 'defining test with template.load_context_template'
      end
    }
    it "should use the template" do
      the_dep.template.should == template
    end
    after {
      source.remove!
    }
  end
  context "with nesting" do
    before {
      @source1, @source2 = Source.new(nil), Source.new(nil)
    }
    it "should maintain the outer context after the inner one returns" do
      Base.sources.load_context :source => @source1 do
        Base.sources.current_load_source.should == @source1
        Base.sources.load_context :source => @source2 do
          Base.sources.current_load_source.should == @source2
        end
        Base.sources.current_load_source.should == @source1
      end
    end
  end
end

describe "template selection during defining" do
  before {
    mock_sources
  }
  context "with namespacing" do
    it "should use templates from the named source" do
      dep('template selection 1', :template => 'source_1:meta_1').template.should == @meta1
    end
    it "should not find the template with the wrong source prefix, and raise" do
      L{
        dep('template selection 2', :template => 'source_2:meta_1').template
      }.should raise_error(TemplateNotFound, "There is no template named 'source_2:meta_1' to define 'template selection 2' against.")
    end
  end
  context "without namespacing" do
    context "with :template option" do
      it "should find a template in the same source" do
        mock_dep('template selection 3', :template => 'meta_1', :in => @source1).template.should == @meta1
      end
      it "should not find a template in the wrong source, and raise" do
        L{
          mock_dep('template selection 4', :template => 'meta_3', :in => @source1).template
        }.should raise_error(TemplateNotFound, "There is no template named 'meta_3' to define 'template selection 4' against.")
      end
    end
    context "with suffixes" do
      it "should find a template in the same source" do
        mock_dep('template selection 3.meta_1', :in => @source1).template.should == @meta1
      end
      it "should find a template in the core source" do
        mock_dep('template selection 3.core_meta', :in => @source1).template.should == @core_meta
      end
      it "should not find a template in the wrong source, and use the base template" do
        mock_dep('template selection 4.meta_3', :in => @source1).template.should == Dep::BaseTemplate
      end
    end
  end
  after {
    Base.sources.anonymous.templates.clear!
    Base.sources.core.templates.clear!
  }
end

describe "template selection during defining from a real source" do
  before {
    @source = Source.new('spec/deps/good', :name => 'good source')
    @source.load!
    Source.stub!(:present).and_return([@source])
  }
  it "should have loaded deps" do
    @source.deps.names.should =~ [
      'test dep 1',
      'test dep 2',
      'option-templated dep',
      'suffix-templated dep.test_template'
    ]
  end
  it "should have loaded templates" do
    @source.templates.names.should =~ [
      'test_template',
      'test_meta_1'
    ]
  end
  it "should have defined deps against the correct template" do
    @source.find('test dep 1').template.should == Dep::BaseTemplate
    @source.find('test dep 2').template.should == Dep::BaseTemplate
    @source.find('option-templated dep').template.should == @source.find_template('test_template')
    @source.find('suffix-templated dep.test_template').template.should == @source.find_template('test_template')
  end
end

describe "nested source loads" do
  before {
    @outer_source = Source.new('spec/deps/outer', :name => 'outer source')
    @nested_source = Source.new('spec/deps/good', :name => 'nested source')

    Source.stub!(:present).and_return([@outer_source, @nested_source])
    @outer_source.load!
  }
  it "should have loaded outer deps" do
    @outer_source.deps.names.should =~ [
      'test dep 1',
      'externally templated',
      'locally templated',
      'locally templated.local_template',
      'separate file',
      'separate file.another_local_template'
    ]
    @nested_source.deps.names.should == []
  end
  it "should have loaded outer templates" do
    @outer_source.templates.names.should =~ [
      'local_template',
      'another_local_template'
    ]
    @nested_source.templates.names.should == []
  end
  context "after defining external deps" do
    before {
      @outer_source.find('externally templated').context
    }
    it "should have loaded the nested deps" do
      @nested_source.deps.names.should =~ [
        'test dep 1',
        'test dep 2',
        'option-templated dep',
        'suffix-templated dep.test_template'
      ]
    end
    it "should have loaded the nested templates" do
      @nested_source.templates.names.should =~ [
        'test_template',
        'test_meta_1'
      ]
    end
  end

  it "should have defined deps against the correct template" do
    @outer_source.find('test dep 1').template.should == Dep::BaseTemplate
    @outer_source.find('externally templated').template.should == @nested_source.find_template('test_template')
    @outer_source.find('locally templated').template.should == @outer_source.find_template('local_template')
    @outer_source.find('locally templated.local_template').template.should == @outer_source.find_template('local_template')
    @outer_source.find('separate file').template.should == @outer_source.find_template('another_local_template')
    @outer_source.find('separate file.another_local_template').template.should == @outer_source.find_template('another_local_template')
  end
end
