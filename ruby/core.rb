require 'json'

# Expander: traces a given grammar downwards, and builds
# text by including terminal symbols and expanding
# non-terminal symbols. This is purely functional; unlike
# the original Python version it doesn't collect the pieces
# by building up state on a fresh object instance. Instead
# it uses recursion, local variables and return values. Use it
# thus:
#
#   Expander.expand(source, grammar)
#
# ...where 'source' is a node on the grammar (hash) itself,
# and 'grammar' is an instance of class Grammar, which stores
# the index of categories. This returns an array of terminal 
# symbols which you can join, or do whatever with.

module Expander 
  extend self

  # expansion rules:
  # - substitutions will replaced with a random selection
  # - choices will be replaced with one of their children
  # - if there's a chance attr, process that
  # - allow the node to apply a filter before returning the result
  def expand(node, grammar)
    # node == nil indicates a no-op, e.g., an empty children array
    return nil unless node

    expansion = if node.is_a?(Hash)
      # i.e., if this is a non-terminal symbol

      # if there's a chance attr, roll the dice
      if node['chance'] && node['chance'].to_i < Randy.chance(100)
        return nil
      end
        
      # substitutions and choices
      if node['type'] == 'substitution'
        expand(Randy.from(grammar.category_index[node['id']]), grammar)
      elsif node['type'] == 'choice'
        expand(Randy.from(node['children']), grammar)
      else
        node['children'].map { |child| expand(child, grammar) }
      end
    else
      # else a terminal symbol
      [node]
    end.flatten.compact
    
    # run the filter, if any. note that filters work on
    # arrays of terminal symbols, not concatenated strings. 
    # if we returned a string, we'd get a no method error on 
    # flatten. the join is the last part of the operation.
    if node['class'] && Filters.respond_to?(node['class'])
      Filters.send(node['class'], expansion)
    else
      expansion
    end
  end
end 

# Grammar: Wraps a hash holding the context-free grammar 
# itself, providing (a) the category index, from ids 
# to arrays of children, for substitutions to pull from 
# and (b) the source to begin parsing on. 
#
# These need to be individuated as stateful objects so we can 
# have multiple grammars in a single runtime, (unlike
# Expander, where the module itself is sufficient)
# but the state in these objects can be regarded as
# immutable after creation, in keeping with the functional
# spirit; think of them as memoized computations.

class Grammar
  # Set up the grammar itself and build the category index
  def initialize(json_grammar)
    @nodes          = JSON.parse(json_grammar)
    @category_index = index_categories_in(nodes, {})
  end

  attr_reader :category_index, :nodes

  def source(id = 'section')
    sources = category_index[id]
    case sources
    when NilClass
      raise GrammarError, "id #{id} does not name a source"
    when Array
      if sources.empty?
        raise GrammarError, "source #{id} is empty"
      end
      Randy.from(sources)
    else
      raise TypeError, "source #{id} isn't an Array"
    end
  end
    
  private

  # Generate a hash of entities keyed by category
  def index_categories_in(node, index)
    if node.class == Hash
      if node['type'] == 'category'
        index[node['id']] = node['children']
      end
      node['children'].each { |child| index_categories_in(child, index) }
    end
    index
  end
end

# Utility methods for selecting a random element of an array. 
# If it seems excessive to wrap this behavior, remember this
# way we can stub it in tests, which we can't do (or, well,
# you know...) if we're calling rand directly/inline.
module Randy
  extend self
  def from(arr)
    arr[rand(arr.length)]
  end
  
  def chance(n = 100)
    rand(n)
  end
end

# Filters allow elements to transform their own output; here
# we have sentences capitalize their first letter and add 
# a space at the end, and paragraphs to add a newline.
module Filters
  extend self

  def sentence(arr)
    (arr << ' ').map { |a| arr.index(a) == 0 ? a.capitalize : a }
  end

  def paragraph(arr)
    arr << "\n"
  end
end

# Generic error class
class GrammarError < StandardError
end
