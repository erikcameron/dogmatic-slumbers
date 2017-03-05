var _  = require('underscore');
var fs = require('fs');

var Expander = {
  expand: function(node, grammar) {
    if (node == undefined) {
      console.log("BAILED ON NODE");
      return undefined;
    }
    
    if (typeof(node) == 'object') {
      /* non-terminal symbol */
      // ch = Random.chance(100);
      // nc = parseInt(node.chance);
      // if (node.chance && (parseInt(node.chance) > Random.chance(100))) {
      if (node.chance) { 
        ch = Random.chance(100);
        nc = parseInt(node.chance);
        if (ch < nc) {
          return undefined;
        } 
      }

      if (node.type == 'substitution') { 
        // _exp = Expander.expand(Random.from(grammar.category_index[node.id]), grammar);
        target = Random.from(grammar.category_index[node.id])
        _exp = Expander.expand(target, grammar);
        
        if (_exp == undefined) {
          console.log('\n\ntarget element is ' + target['type']);
          console.log('it has ' + target.children.length + ' children are:');
          _.each(target.children, function(c) { console.log(c); });
          console.log('\n');
        }
      } else if (node.type == 'choice') {
        _exp = Expander.expand(Random.from(node.children), grammar);
      } else {
        _exp = node.children.map(function(child) { 
          return Expander.expand(child, grammar);
        });
      }
    } else {
      /* terminal symbol */
      _exp = [node]
    }
    
    var expansion = _.flatten(_.compact(_exp));

    if (node.class && typeof(Filters[node.class]) == 'function') {
      console.log("expansion is " + expansion);
      // return Filters[node.class](expansion);
      return expansion;
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
    // return arr[Random.chance(arr.length)];
    ch = Random.chance(arr.length);
    // console.log('chance is ' + ch + ' out of ' + arr.length);
    // console.log('returning ' + arr[ch] + '...');
    return arr[ch];
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
