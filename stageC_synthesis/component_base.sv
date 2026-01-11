class component_base;
  string name;
  component_base parent;

  function new(string name, component_base parent = null);
    this.name = name;
    this.parent = parent;
  endfunction

  // Build the full path name for debug printing
  function string pathname();
    if (parent == null)
      return name;
    else
      return {parent.pathname(), ".", name};
  endfunction

  function void print();
    $display("component: %s", pathname());
  endfunction
endclass
