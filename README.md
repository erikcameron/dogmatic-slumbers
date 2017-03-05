# Dogmatic Slumbers

When I was in college we had a great deal of fun with the Kant Generator, a program that does
exactly what it says on the box: Generate streams of pseudo-Immanuel Kant, possibly to be cut
and pasted verbatim into long surreal emails to campus lists. (But I digress.) It was written
by [Mark Pilgrim](https://en.wikipedia.org/wiki/Mark_Pilgrim) for Python 2 at some point prior to time 
immemorial, and wound up in his 2004 book _Dive Into Python_. It's an example of a [context-free 
grammar](https://www.cs.rochester.edu/~nelson/courses/csc_173/grammars/cfg.html).

A friend had been asking me for a while to get one running, so I tracked down the code. It
worked, but a few issues cropped up. First, it depends on Python 2, which is less than ideal. 
The first plan was a more-or-less straightforward transliteration of the program into contemporary
Ruby. (This is not a Ruby vs. Python thing. I wanted something in a modern runtime I could 
churn out quickly, so.) This worked, but a few other things stuck in my craw along the way.

In DiP, the Kant Generator shows up in a
[chapter](http://www.diveintopython.net/xml_processing/) "about XML
processing," which in 2017 is probably the least interesting thing going on here, at least
from an instructional point of view. The more relevant aspects these days are probably context-free
grammars and recursively building a data structure. (These aspects are mentioned more obliquely in
DiP.) So I decided to rewrite it from the ground up to focus on those issues. My goals were:

- The given implementation is imperative and based on the mutable state of an object. For a 2004
lesson about XML parsing that's sensible, but these days people are realizing that mutable
state is their enemy, and [functional thinking is their friend](https://www.fpcomplete.com/blog/2012/04/the-downfall-of-imperative-programming). So I wanted to rewrite it in a functional idiom.
- The format of the grammars themselves seemed less than ideal:
    * XML is used less nowadays,
    * The vagaries of the format didn't help: Nokogiri had different ideas about
      newlines and whitespace than the original Python package, for
      example. This absolutely could have been due to user error, but the
      linear, text vs. "hypertext" nature of XML (designed for inline
      markup) is really superfluous to defining structured data. JSON,
      for example, reads only a clean data structure, and does not care
      about newlines in the source file. (And JSON is used more nowadays.)
    * The grammars themselves were a little semantically weird, mainly in their use of the `<p>` tag.
      In the original grammars, `<p>` doesn't denote a paragraph at all; it's rather an all purpose
      container for other elements, onto which you can project certain properties. (See below.)
      Calling these 'paragraphs' seems to just muddy the waters. The sense of `<ref>` and `<xref>` is
      a little vague, too.

The eventual decision was to do simultaneous Ruby and Javascript versions,
to see how well the relevant stuff mapped onto each other, and use JSON
for the grammar.  The name of the rewrite is "Dogmatic Slumbers" is in honor of [Kant's
awakening](https://plato.stanford.edu/entries/kant-hume-causality/#KanAnsHum),
and because the output sounds like the man himself on his way down an
Ambien hole.

## CFGs

A context-free grammar, using the terminology given [here](https://www.cs.rochester.edu/~nelson/courses/csc_173/grammars/cfg.html), is composed of:
- "Terminal symbols," those that should be reproduced in the output as is;
- "nonterminal symbols," which are expanded to terminal symbols, or other nonterminals, via
- "productions," the rules that explain how those expansions work, and
- a "start symbol", which is just whatever nonterminal symbol at which expansion begins. (Here this
a "section," but you can begin expanding on any nonterminal symbol.)  

The start symbol is expanded. If the expansion contains any nonterminals, those too are expanded.
The process repeates recursively until the expansion contains only terminal symbols. These are
then concatenated and returned as the output.

This leaves us with a pretty simple selection of types: In our JSON output, we'll represent 
terminal symbols with string literals, and nonterminal symbols as objects. (Or hashes, in
Ruby-ese.) 

## Converting the grammars

First we want to convert the XML grammars to JSON, and give the elements more specific
names. The grammars provided with the program utilize the following elements:

- `<ref>`, a reference to a category of some kind; this might be a linguistic unit (paragraph, sentence, clause) or something more specific (philosophers, modes of knowledge, etc. for the Kant grammar). The children of these tags are the members of that category;
- `<xref>`, a cross-reference to one such category, whose name is given in the `id` attribute. This is like a blank in a Madlib: when the output is generated, the `<xref>` will be replaced with an instance of the category given; (note that the substitution may itself contain further expansions)
- `<p>`, used to wrap string literals, or further children; mainly a spike on which to hang options;
  like `class="sentence"` (i.e., capitalize the first word) or `chance="50"` (i.e., roll the dice on a 50% chance of this elements children being included in the output); 
- `<choice>`, indicating that this tag should be replaced with one of its child elements chosen at random;
- `<grammar>`, the tag containing the grammar itself.

As noted, some of these are a little opaque. We'll rename these in the process of converting them. Here
are their new names, straight from the converter source:

```ruby
  ELEMENT_MAP = { 'ref' => 'category',
    'xref'    => 'substitution',
    'choice'  => 'choice',
    'p'       => 'box',
    'grammar' => 'grammar' }
```

"Cateogories" contain things. "Substitutions" are swapped out for an instance of their associated
category, chosen at random. "Choices" as before are swapped out for one of their children. "Boxes"
are containers that we use to control the output of their children, (e.g., to capitalize sentences),
and the grammar tag is the root node. 

The converter is written in Ruby and uses Nokogiri for XML parsing. Converting an existing grammar 
proceeds by recursively calling the `parse_node` method, beginning with the node representing
the grammar itself. This method is pretty simple:

```ruby
  def parse_node(node)
    if node.class == Nokogiri::XML::Text
      parse_text_node(node)
    elsif node.class == Nokogiri::XML::Element
      parse_element_node(node)
    else
      raise TypeError, "don't know what to do with node #{node}"
    end
  end
```

All instances of `Nokogiri::XML::Text` become string literals:

```ruby
  def parse_text_node(node)
    node.text
  end
```

Instances of `Nokogiri::XML::Element` are converted into a hash. 
```ruby
   def parse_element_node(node)
```
Three things to do here:
- Create a hash to represent this node, with the type of element keyed under `type`:

```ruby
    nodehash = { 'type' => ELEMENT_MAP[node.name] || 'unknown' }
```

- Set the attributes used as key/value pairs in the hash:

```ruby
    ['id', 'class', 'chance'].each do |attr|
      nodehash[attr] = node.attributes[attr].value if node.attributes[attr]
    end
```

- Make the value of `children` the array returned by mapping the nodes children to `parse_node`:

```ruby
    nodehash['children'] = node.children.map { |n| parse_node(n) }
```

- ...and return the hash:

```ruby
    nodehash
  end
```

That's it. Calling `parse_node` on the grammar element will return one big hash representing 
the entire grammar. From there, we just send it to `JSON.pretty_generate` (so we can read the 
output) and dump it to a file. See the source for both the XML inputs (from the original Kant Generator)
and the JSON outputs.

## Rewriting the code

### The original version

The original Python defines a class, `KantGenerator`, instances of which keep in their own
state both (a) the parsed grammar and (b) an output buffer which is cumulatively filled 
with terminal symbols; the buffer is joined and returned as the output. The initializer
gives a pretty good overview of how the state is set up:

```python
class KantGenerator
  """generates mock philosophy based on a context-free grammar"""

  def __init__(self, grammar, source=None):
    self.loadGrammar(grammar)
    self.loadSource(source and source or self.getDefaultSource())
    self.refresh
```

That is: (1) The grammar is loaded, by parsing the XML and creating
a dictionary/hash/etc. where the keys are `refs` (or "categories," in
our terms) and the values are arrays of those entities. (2) A "source,"
i.e., the start symbol, is selected; if the user doesn't provide one,
the default will be chosen from among the non-terminal symbols of the
grammar. (3) The internal state is wiped/initialized. This consists of
an output buffer (`self.pieces = []`) and a flag to capitalize the next
word (`self.capitalizeNextWord = 0`; more on this below).

Output is generated by calling the `parse` method on a node. (`refresh`
does this for you; since that's called from `__init__`, when you make a
new `KantGenerator`, the buffer is already full by the time you get the 
new object back.) This is a dispatch that determines the correct method
to call by inspecting the node type; it will ultimately call one of
`parse_Document`, `parse_Text`, `parse_Element`, or `parse_Comment`. The
`parse_Text` method appends the node text to the buffer, capitalizing if
the flag is set. The `parse_Element` method similarly dispatches to one of
`do_p`, `do_xref`, or `do_choice` depending on the element type. And so
on. Output is returned when there are no more nonterminal symbols (i.e.,
elements) to parse. 

```python
  k = KantGenerator(grammar, source)
  print k.output()
```

Finally, the `output` method concatenates everything
in the buffer and returns a string. To generate a new block of text,
you call `refresh` to wipe/rebuild the internal state. (Or just make a
new object.)


### The rewrite

The original builds up mutable state on an object, but this really isn't
necessary, and these days should probably be avoided when possible. The
"expansion" (i.e., the output) can be thought of as a function from a
source and grammar to an output string, where the content of the function
is (basically) the production rules. So we'll start there.

One good rule of thumb for writing in a "functional" style is to restrict
yourself to local variables and return values; i.e., to eschew "instance
variables," "attributes," "properties," or whatever your language
calls a piece of state like that, that are scoped to an object. That
way, any state is built up on the call stack.  When the stack unwinds,
(i.e., as functions/methods return) values are destroyed; there are no
enduring data structures that may be referenced (and therefore mutated)
elsewhere. It's like a _very_ effective form of data hiding: variables
local to another stack frame really are private.

Another corollary of this approach: Suppose an exception is raised somewhere
in the expansion process, and then caught by the method calling the expansion.
If we were cumulatively filling an output buffer we'd be left with an 
object in an inconsistent state, i.e., a partially completed expansion. In
our functional version, there is no opportunity for inconsistent state. The
expand method either returns or it doesn't; an exception will unwind the
stack and destroy the partial expansion before the calling method ever gets
a chance to bind it to a variable. So no inconsistent state. (This may seem
trivial here but it's easy to imagine cases where it isn't, and you'd want
that guarantee.)

We'll call this function `expand`. Because
it's "purely functional," we can treat it like what some languages call
a "static method," i.e., one with no associated receiver object (other than 
a class, module, etc.). In Ruby, we'll do this by calling `extend self` on a module:

```ruby
module Expander
  extend self
  
  def expand(node, grammar) 
    ...
  end
end
```

In JS, we can use a global as a package:

```javascript
var Expander = {
  expand: function(node, grammar) {
    ...
  }
}
```
Then, in either language:

```ruby
Expander.expand(node, grammar)
```

`node` is
point on the grammar to start processing, and `grammar` is the grammar
object itself, passed in to provide access to the category index for
substitutions. See the source for the respective Ruby/JS implementations.
In pseudocode, the algorithm is as follows:

```
  expand(node, grammar)
    if node is nil, return nil for a no-op;

    if the node is a hash/object (i.e., a non-terminal), then:
      if this node has a chance attribute, roll the dice against it;
        if failure, return nil
        if success, keep going
    
      if this node is of type 'subsitution' then:
        call expand on a random child of the category named by this node's id attribute
      or if this node is of type 'choice'
        call expand on a random child of this node
      otherwise
        map this node's children to the value of calling expand on them
    
    otherwise (i.e., if the node is not a hash/object it is a string literal)
      send back an array containing only this node    

    take the (array) value returned by the preceding if block, flatten it, and:
    if there is a filter defined for this node's class:
      send the expansion to the Filter and return the value
    otherwise:
      return the expansion itself
```

All values are passed either by return or in the argument vector, and all
variables allocated are local variables. The return value of `expand`, at
any point in the recursion, is an array of terminal symbols. These arrays
replace the mutable-state output buffer in the original. When the original
call to `expand` returns, that array is joined and returned as output.

### Grammar objects

The original also combined the expansion methods in the same class as the
grammar parsing. For 
[SRP reasons](https://en.wikipedia.org/wiki/Single_responsibility_principle) 
we separate them. `Grammar` is a Ruby class and a JS prototype; instances
wrap a single grammar, and provide two methods, `source` to provide a
start symbol, and `category_index`, to expose the mapping from category
ids to categories. In both languages, the Grammar object parses its
grammar on initialization. We do store the grammar hash and category
index as instance variables, but because they may be regarded as
immutable, this doesn't (at least in spirit) violate our commitment
to a functional idiom.  Think of them as memoized computations, which
are common in functional programming: The grammar is parsed (computed,
transformed) once at initialization and then saved for reference.

These are simple: On initialization, they take a string of JSON, (say, 
read out of one of the included files) parse it, store the resulting
hash as `nodes`, and build the category index:

```ruby
# Ruby
  attr_accessor :category_index

  def initialize(json_grammar)
    @nodes          = JSON.parse(json_grammar)
    @category_index = index_categories_in(nodes, {})
  end
```

```Javascript
// JS
var Grammar = function(json_grammar) {
  this.nodes          = JSON.parse(json_grammar);
  this.category_index = this.index_categories_in(this.nodes, {});
}
```

The `source` method/function returns a randomly selected instance of
some category as a start symbol.  It takes an optional argument, `id`,
which will be the category from which the start symbol is selected;
`id` defaults to 'section'. (Note that you could specify some other
source, say, 'question' or 'throwaway assertion' to make a section heading.
Any node can in principle be treated as a start symbol.)

## Conclusion

This is a very silly program that hopefully demonstrates some handy
practices.  It is also useful for annoying/alarming your friends. All
of the grammars from the original are included. If you make a new one
let me know!
