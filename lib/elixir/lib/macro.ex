import Kernel, except: [to_string: 1]

defmodule Macro do
  @moduledoc """
  This module provides conveniences for working with macros.
  """

  @doc """
  Returns a list of binary operators. This is available
  as a macro so it can be used in guard clauses.
  """
  defmacro binary_ops do
    [
      :===, :!==,
      :==, :!=, :<=, :>=,
      :&&, :||, :<>, :++, :--, :**, ://, :::, :<-, :.., :|>, :=~,
      :<, :>, :->,
      :+, :-, :*, :/, :=, :|, :.,
      :and, :or, :xor, :when, :in, :inlist, :inbits,
      :<<<, :>>>, :|||, :&&&, :^^^
    ]
  end

  @doc """
  Returns a list of unary operators. This is available
  as a macro so it can be used in guard clauses.
  """
  defmacro unary_ops do
    [:!, :@, :^, :not, :+, :-, :~~~, :&]
  end

  @doc """
  Receives an expresion representing a possible definition
  and extracts its arguments. It returns a tuple with the
  function name and the arguments list or `:error` if not
  a valid call syntax.

  This is useful for macros that want to provide the same
  arguments syntax available in def/defp/defmacro and friends.

  ## Examples

      extract_args(quote do: foo)        == { :foo, [] }
      extract_args(quote do: foo())      == { :foo, [] }
      extract_args(quote do: foo(1, 2, 3)) == { :foo, [1, 2, 3] }
      extract_args(quote do: 1.(1, 2, 3))  == :error

  """
  def extract_args(expr) do
    :elixir_clauses.extract_args(expr)
  end

  @doc """
  Recursively escapes a value so it can be inserted
  into a syntax tree.

  ## Examples

      iex> Macro.escape(:foo)
      :foo

      iex> Macro.escape({ :a, :b, :c })
      { :{}, [], [:a, :b, :c] }

  """
  def escape(expr) do
    :elixir_quote.escape(expr, false) |> elem(0)
  end

  @doc false
  def escape_quoted(expr) do
    :elixir_quote.escape(expr, true) |> elem(0)
  end

  @doc %B"""
  Unescape the given chars. This is the unescaping behavior
  used by default in Elixir single- and double-quoted strings.
  Check `unescape_binary/2` for information on how to customize
  the escaping map.

  In this setup, Elixir will escape the following: `\a`, `\b`,
  `\d`, `\e`, `\f`, `\n`, `\r`, `\s`, `\t` and `\v`. Octals are
  also escaped according to the latin1 set they represent.

  This function is commonly used on sigil implementations
  (like `%r`, `%b` and others).

  ## Examples

      iex> Macro.unescape_binary("example\\n")
      "example\n"

  In the example above, we pass a string with `\n` escaped
  and we return a version with it unescaped.
  """
  def unescape_binary(chars) do
    :elixir_interpolation.unescape_chars(chars)
  end

  @doc %B"""
  Unescape the given chars according to the map given.
  Check `unescape_binary/1` if you want to use the same map
  as Elixir single- and double-quoted strings.

  ## Map

  The map must be a function. The function receives an integer
  representing the number of the characters it wants to unescape.
  Here is the default mapping function implemented by Elixir:

      def unescape_map(?a), do: ?\a
      def unescape_map(?b), do: ?\b
      def unescape_map(?d), do: ?\d
      def unescape_map(?e), do: ?\e
      def unescape_map(?f), do: ?\f
      def unescape_map(?n), do: ?\n
      def unescape_map(?r), do: ?\r
      def unescape_map(?s), do: ?\s
      def unescape_map(?t), do: ?\t
      def unescape_map(?v), do: ?\v
      def unescape_map(e),  do: e

  If the `unescape_map` function returns false. The char is
  not escaped and `\` is kept in the char list.

  ## Octals

  Octals will by default be escaped unless the map function
  returns false for ?0.

  ## Hex

  Octals will by default be escaped unless the map function
  returns false for ?x.

  ## Examples

  Using the unescape_map defined above is easy:

      Macro.unescape_binary "example\\n", unescape_map(&1)

  """
  def unescape_binary(chars, map) do
    :elixir_interpolation.unescape_chars(chars, map)
  end

  @doc """
  Unescape the given tokens according to the default map.
  Check `unescape_binary/1` and `unescape_binary/2` for more
  information about unescaping.

  Only tokens that are binaries are unescaped, all others are
  ignored. This function is useful when implementing your own
  sigils. Check the implementation of `Kernel.__b__`
  for examples.
  """
  def unescape_tokens(tokens) do
    :elixir_interpolation.unescape_tokens(tokens)
  end

  @doc """
  Unescape the given tokens according to the given map.
  Check `unescape_tokens/1` and `unescape_binary/2` for more information.
  """
  def unescape_tokens(tokens, map) do
    :elixir_interpolation.unescape_tokens(tokens, map)
  end

  @doc false
  def to_binary(tree) do
    IO.write "[WARNING] Macro.to_binary is deprecated, please use Macro.to_string instead\n#{Exception.format_stacktrace}"
    to_string(tree)
  end

  @doc """
  Converts the given expression to a binary.

  ## Examples

      iex> Macro.to_string(quote do: foo.bar(1, 2, 3))
      "foo.bar(1, 2, 3)"

  """
  def to_string(tree)

  # Variables
  def to_string({ var, _, atom }) when is_atom(atom) do
    atom_to_binary(var, :utf8)
  end

  # Aliases
  def to_string({ :__aliases__, _, refs }) do
    Enum.map_join(refs, ".", call_to_string(&1))
  end

  # Blocks
  def to_string({ :__block__, _, [expr] }) do
    to_string(expr)
  end

  def to_string({ :__block__, _, _ } = expr) do
    block = adjust_new_lines block_to_string(expr), "\n  "
    "(\n  " <> block <> "\n)"
  end

  # Bits containers
  def to_string({ :<<>>, _, args }) do
    "<<" <> Enum.map_join(args, ", ", to_string(&1)) <> ">>"
  end

  # Tuple containers
  def to_string({ :{}, _, args }) do
    "{" <> Enum.map_join(args, ", ", to_string(&1)) <> "}"
  end

  # List containers
  def to_string({ :[], _, args }) do
    "[" <> Enum.map_join(args, ", ", to_string(&1)) <> "]"
  end

  # Fn keyword
  def to_string({ :fn, _, [[do: { :->, _, [{_, _, tuple}] } = arrow]] })
      when not is_tuple(tuple) or elem(tuple, 0) != :__block__ do
    "fn " <> arrow_to_string(arrow) <> " end"
  end

  def to_string({ :fn, _, [[do: { :->, _, [_] } = block]] }) do
    "fn " <> block_to_string(block) <> "\nend"
  end

  def to_string({ :fn, _, [[do: block]] }) do
    block = adjust_new_lines block_to_string(block), "\n  "
    "fn\n  " <> block <> "\nend"
  end

  # Partial call
  def to_string({ :&, _, [num] }) do
    "&#{num}"
  end

  # left -> right
  def to_string({ :->, _, _ } = arrow) do
    "(" <> arrow_to_string(arrow, true) <> ")"
  end

  # Binary ops
  def to_string({ op, _, [left, right] }) when op in binary_ops do
    op_to_string(left) <> " #{op} " <> op_to_string(right)
  end

  # Splat when
  def to_string({ :when, _, args }) do
    { left, right } = :elixir_tree_helpers.split_last(args)
    "(" <> Enum.map_join(left, ", ", to_string(&1)) <> ") when " <> to_string(right)
  end

  # Unary ops
  def to_string({ :not, _, [arg] })  do
    "not " <> to_string(arg)
  end

  def to_string({ op, _, [arg] }) when op in unary_ops do
    atom_to_binary(op, :utf8) <> to_string(arg)
  end

  # All other calls
  def to_string({ target, _, args }) when is_list(args) do
    { list, last } = :elixir_tree_helpers.split_last(args)
    case is_kw_blocks?(last) do
      true  -> call_to_string_with_args(target, list) <> kw_blocks_to_string(last)
      false -> call_to_string_with_args(target, args)
    end
  end

  # Two-item tuples
  def to_string({ left, right }) do
    to_string({ :{}, [], [left, right] })
  end

  # Lists
  def to_string(list) when is_list(list) do
    to_string({ :[], [], list })
  end

  # All other structures
  def to_string(other), do: inspect(other, raw: true)

  # Block keywords
  defmacrop kw_keywords, do: [:do, :catch, :rescue, :after, :else]

  defp is_kw_blocks?([_|_] = kw) do
    Enum.all?(kw, match?({x, _} when x in kw_keywords, &1))
  end
  defp is_kw_blocks?(_), do: false

  defp module_to_string(atom) when is_atom(atom), do: inspect(atom, raw: true)
  defp module_to_string(other), do: call_to_string(other)

  defp call_to_string(atom) when is_atom(atom),  do: atom_to_binary(atom, :utf8)
  defp call_to_string({ :., _, [arg] }),         do: module_to_string(arg) <> "."
  defp call_to_string({ :., _, [left, right] }), do: module_to_string(left) <> "." <> call_to_string(right)
  defp call_to_string(other),                    do: to_string(other)

  defp call_to_string_with_args(target, args) do
    args = Enum.map_join(args, ", ", to_string(&1))
    call_to_string(target) <> "(" <> args <> ")"
  end

  defp kw_blocks_to_string(kw) do
    Enum.reduce(kw_keywords, " ", fn(x, acc) ->
      case Keyword.has_key?(kw, x) do
        true  -> acc <> kw_block_to_string(x, Keyword.get(kw, x))
        false -> acc
      end
    end) <> "end"
  end

  defp kw_block_to_string(key, value) do
    block = adjust_new_lines block_to_string(value), "\n  "
    atom_to_binary(key, :utf8) <> "\n  " <> block <> "\n"
  end

  defp block_to_string({ :->, _, exprs }) do
    Enum.map_join(exprs, "\n", fn({ left, _, right }) ->
      left = comma_join_or_empty_paren(left, false)
      left <> "->\n  " <> adjust_new_lines block_to_string(right), "\n  "
    end)
  end

  defp block_to_string({ :__block__, _, exprs }) do
    Enum.map_join(exprs, "\n", to_string(&1))
  end

  defp block_to_string(other), do: to_string(other)

  defp op_to_string({ op, _, [_, _] } = expr) when op in binary_ops do
    "(" <> to_string(expr) <> ")"
  end

  defp op_to_string(expr), do: to_string(expr)

  defp arrow_to_string({ :->, _, pairs }, paren // false) do
    Enum.map_join(pairs, "; ", fn({ left, _, right }) ->
      left = comma_join_or_empty_paren(left, paren)
      left <> "-> " <> to_string(right)
    end)
  end

  defp comma_join_or_empty_paren([], true),  do: "() "
  defp comma_join_or_empty_paren([], false), do: ""

  defp comma_join_or_empty_paren(left, _) do
    Enum.map_join(left, ", ", to_string(&1)) <> " "
  end

  defp adjust_new_lines(block, replacement) do
    bc <<x>> inbits block do
      << case x == ?\n do
        true  -> replacement
        false -> <<x>>
      end :: binary >>
    end
  end

  @doc """
  Receives an expression representation and expands it. The following
  contents are expanded:

  * Macros (local or remote);
  * Aliases are expanded (if possible) and return atoms;
  * All pseudo-variables (__FILE__, __MODULE__, etc);
  * Module attributes reader (@foo);

  In case the expression cannot be expanded, it returns the expression itself.

  Notice that `Macro.expand` is not recursive and it does not
  expand child expressions. In this example:

    Macro.expand(quote(do: var && some_macro), __ENV__)

  `var && some_macro` will expand to something like:

      case var do
        _ in [false, nil] -> var
        _ -> some_macro
      end

  Notice that the `&&` operator is a macro that expands to a case.
  Even though `some_macro` is also a macro, it is not expanded
  because it is a child expression given to `&&` as argument.

  ## Examples

  In the example below, we have a macro that generates a module
  with a function named `name_length` that returns the length
  of the module name. The value of this function will be calculated
  at compilation time and not at runtime.

  Consider the implementation below:

      defmacro defmodule_with_length(name, do: block) do
        length = length(atom_to_list(name))

        quote do
          defmodule unquote(name) do
            def name_length, do: unquote(length)
            unquote(block)
          end
        end
      end

  When invoked like this:

      defmodule_with_length My.Module do
        def other_function, do: ...
      end

  The compilation will fail because `My.Module` when quoted
  is not an atom, but a syntax tree as follow:

      {:__aliases__, [], [:My, :Module] }

  That said, we need to expand the aliases node above to an
  atom, so we can retrieve its length. Expanding the node is
  not straight-forward because we also need to expand the
  caller aliases. For example:

      alias MyHelpers, as: My

      defmodule_with_length My.Module do
        def other_function, do: ...
      end

  The final module name will be `MyHelpers.Module` and not
  `My.Module`. With `Macro.expand`, such aliases are taken
  into consideration. Local and remote macros are also
  expanded. We could rewrite our macro above to use this
  function as:

      defmacro defmodule_with_length(name, do: block) do
        expanded = Macro.expand(name, __CALLER__)
        length   = length(atom_to_list(expanded))

        quote do
          defmodule unquote(name) do
            def name_length, do: unquote(length)
            unquote(block)
          end
        end
      end

  """
  def expand(aliases, env) do
    expand(aliases, env, nil)
  end

  defp expand({ :__aliases__, _, _ } = original, env, cache) do
    case :elixir_aliases.expand(original, env.aliases, env.macro_aliases) do
      atom when is_atom(atom) -> atom
      aliases ->
        aliases = lc alias inlist aliases, do: expand(alias, env, cache)

        case :lists.all(is_atom(&1), aliases) do
          true  -> :elixir_aliases.concat(aliases)
          false -> original
        end
    end
  end

  # Expand @ calls
  defp expand({ :@, _, [{ name, _, args }] } = original, env, _cache) when is_atom(args) or args == [] do
    case (module = env.module) && Module.open?(module) do
      true  -> Module.get_attribute(module, name)
      false -> original
    end
  end

  # Expand pseudo-variables
  defp expand({ :__MODULE__, _, atom }, env, _cache) when is_atom(atom), do: env.module
  defp expand({ :__FILE__, _, atom }, env, _cache)   when is_atom(atom), do: env.file
  defp expand({ :__DIR__, _, atom }, env, _cache)    when is_atom(atom), do: :filename.dirname(env.file)
  defp expand({ :__ENV__, _, atom }, env, _cache)    when is_atom(atom), do: env

  # Expand possible macro import invocation
  defp expand({ atom, line, args } = original, env, cache) when is_atom(atom) do
    args = case is_atom(args) do
      true  -> []
      false -> args
    end

    case not is_partial?(args) do
      false -> original
      true  ->
        module = env.module

        extra  = if function_exported?(module, :__info__, 1) do
          [{ module, module.__info__(:macros) }]
        else
          []
        end

        expand = :elixir_dispatch.expand_import(line, { atom, length(args) }, args,
          env.module, extra, to_erl_env(env, cache))
        case expand do
          { :ok, _, expanded } -> expanded
          { :error, _ }     -> original
        end
    end
  end

  # Expand possible macro require invocation
  defp expand({ { :., _, [left, right] }, line, args } = original, env, cache) when is_atom(right) do
    receiver = expand(left, env)

    case is_atom(receiver) and not is_partial?(args) do
      false -> original
      true  ->
        expand = :elixir_dispatch.expand_require(line, receiver, { right, length(args) },
          args, env.module, to_erl_env(env, cache))
        case expand do
          { :ok, _receiver, expanded } -> expanded
          { :error, _ }                -> original
        end
    end
  end

  # Anything else is just returned
  defp expand(other, _env, _cache), do: other

  defp to_erl_env(env, nil),    do: :elixir_scope.to_erl_env(env)
  defp to_erl_env(_env, cache), do: cache

  ## Helpers

  defp is_partial?(args) do
    :lists.any(match?({ :&, _, [_] }, &1), args)
  end

  @doc """
  Recurs the quoted expression checking if all sub terms are
  safe (i.e. they represented data structured and don't actually
  evaluate code) and returns `:ok` unless a given term is unsafe,
  which is returned as `{ :unsafe, term }`.
  """
  def safe_term(terms) do
    do_safe_term(terms) || :ok
  end

  defp do_safe_term({ local, _, terms }) when local in [:{}, :[], :__aliases__] do
    do_safe_term(terms)
  end

  defp do_safe_term({ unary, _, [term] }) when unary in [:+, :-] do
    do_safe_term(term)
  end

  defp do_safe_term({ left, right }), do: do_safe_term(left) || do_safe_term(right)
  defp do_safe_term(terms) when is_list(terms),  do: Enum.find_value(terms, do_safe_term(&1))
  defp do_safe_term(terms) when is_tuple(terms), do: { :unsafe, terms }
  defp do_safe_term(_), do: nil
end
