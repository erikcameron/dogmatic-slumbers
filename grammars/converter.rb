# convert the DiP XML format into our JSON representation:
#   - text objects -> string literals (i.e., terminal symbols)
#   - elements -> hashes (i.e., non-terminal syms)
#     - <p> -> "box"
#     - <ref> -> "category"
#     - <xref> -> "substitution"
#     - <choice> -> "choice"
#     - <grammar> -> "grammar"

require 'nokogiri'
require 'json'

# in the functional spirit, we don't actually need stateful objects to do this:
#   GrammarToJson.convert('/path/to/input.xml', '/path/to/output.json')
module GrammarToJson
  extend self

  # stick with good old hashrocket style
  # here as we want string keys, not syms
  ELEMENT_MAP = { 'ref' => 'category',
    'xref'    => 'substitution',
    'choice'  => 'choice',
    'p'       => 'box',
    'grammar' => 'grammar' }

  def convert(input_path, output_path)
    File.open(output_path, 'w') do |f|
      f.write(JSON.pretty_generate(generate_grammar_hash(input_path)))
    end
  end

  def generate_grammar_hash(input_path)
    xml = Nokogiri::XML.parse(open(input_path)) do |cfg|
      cfg.noblanks
    end
    # 'xml' represents the entire doc and has two children,
    # the former is the DTD (pitch it), the latter is the grammar
    # itself
    parse_node(xml.children.last)
  end  
  
  private

  def parse_node(node)
    if node.class == Nokogiri::XML::Text
      parse_text_node(node)
    elsif node.class == Nokogiri::XML::Element
      parse_element_node(node)
    else
      raise TypeError, "don't know what to do with node #{node}"
    end
  end

  def parse_text_node(node)
    node.text
  end

  def parse_element_node(node)
    # there are three attributes used in the original XML:
    #   - id
    #   - class
    #   - chance
    nodehash = { 'type' => ELEMENT_MAP[node.name] || 'unknown' }
    ['id', 'class', 'chance'].each do |attr| 
      nodehash[attr] = node.attributes[attr].value if node.attributes[attr]
    end
    nodehash['children'] = node.children.map { |n| parse_node(n) }
    nodehash
  end
end   
