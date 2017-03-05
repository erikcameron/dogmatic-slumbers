var _ = require('underscore');
var fs = require('fs');

var Expander = {
  expand: function(node, grammar) {
    if (node == undefined) {
      return undefined;
    }
    
    if (typeof(node) == 'object') {
      // console.log(1);
      /* non-terminal symbol */
      if (node.chance && parseInt(node.chance) < Random.chance(100)) {
        // console.log(2);
        return undefined;
      }

      if (node.type == 'substitution') { 
        // console.log(3);
        _exp = Expander.expand(Random.from(grammar.category_index[node.id]), grammar);
      } else if (node.type == 'choice') {
        // console.log(4);
        _exp = Expander.expand(Random.from(node.children), grammar);
      } else {
        // console.log(5);
        _exp = node.children.map(function(child) { 
          return Expander.expand(child, grammar);
        });
      }
    } else {
      // console.log(6);
      /* terminal symbol */
      _exp = [node]
      // console.log("_exp is " + _exp);
    }
    
    var expansion = _.flatten(_.compact(_exp));
    // var expansion = _exp

    // if (node.class && typeof(Filters[node.class]) == 'function') {
    if (false && node.class && typeof(Filters[node.class]) == 'function') {
      return Filters[node.class](expansion);
    } else {
      return expansion;
    }
  }
}


var Grammar = function(json_grammar) {
  this.nodes          = JSON.parse(json_grammar);
  this.category_index = this.index_categories_in(this.nodes, {});
}

Grammar.prototype.source = function(id) {
  id = id == undefined ? 'section' : id;

  var sources = this.category_index[id];
  /* come back to the error checking here */
  return Random.from(sources);
}

Grammar.prototype.index_categories_in = function(node, index) {
  if (typeof(node) == 'object') {
    if (node.type == 'category') {
      index[node.id] = node.children;
    }
    _.each(node.children, function(child) {
      this.index_categories_in(child, index);
    }, this);
  }
  return index;
}


var Random = {
  chance: function(limit) {
    return Math.floor(Math.random() * limit);
  },

  from: function(arr) {
    return arr[Random.chance(arr.length)];
  }
}

var Filters = {
  sentence: function(arr) {
    arr.push(' ');
    _.map(arr, function(x) { 
      if(arr.indexOf(x) == 0) {
        return x.charAt(0).toUpperCase() + x.slice(1);
      } else {
        return x;
      }
    });
  }, 

  paragraph: function(arr) {  
    arr.push('\n');
    return arr;
  }
}


var g = new Grammar(fs.readFileSync('../grammars/json/kant.json'));
console.log(Expander.expand(g.source(), g).join());
// console.log(g.source());
// console.log(Random.chance(100));

// // console.log(Random.from(g.category_index['conjunction']));
