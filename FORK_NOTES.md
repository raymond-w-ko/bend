# Fork notes

This is raymond-w-ko/bend, a fork of bendlang/bend for programs whose
Bend is compiled to JavaScript and run in the browser, where the hot
code walks lists, updates records by index and calls small predicates
millions of times. These notes say what the fork changes, why, what we
learned doing it, and why the changes would likely not be merged
upstream as they are. Read them before you rebase the fork, or before
you send anything upstream.

All changes are in `bend2/base.bend` and `bend2/comp.ts` (the JS emitter
and its runtime), with a test each in `tests/compile/`. `bend2/bend.ts`
(the language, human-written) is untouched.

## The changes

1. **`Vec<A>`** (`base.bend`; `comp.ts`: `OPTIMIZED.Vec`, the `vec_*`
   operations, `vec_set`/`vec_push`/`vec_from_list`/`vec_to_list` in the
   JS runtime). A list of `Data` that JS keeps as an array. The checker
   and the proofs see a plain list (`VNil`, `VCon`), and the C lane runs
   Base's own recursive defs (the operations have no `C` text). In JS,
   `Vec.length`, `Vec.get` and `Vec.at` take one step, and `Vec.set`,
   `Vec.push` and `Vec.take` copy the array once. It is never written in
   place, so unlike `Array` it is `Data`: shared and copied freely, with
   no linear threading of the owner. A `match` on a `Vec` slices its tail
   (O(n) a step): walk one by index. Test: `tests/compile/vec_ops.bend`.

   Why not `Array`: `Array` is linear (`Type`), so every read must hand
   the array back (`Array.get` returns a pair), and Bend refuses to
   destructure a computed value (a match takes a parameter or a pattern's
   field only), so each read needs a helper def. A large program in that
   style would need thousands of helpers, and its proofs would have to
   reason about `Array`'s 32-bit index tree, for which Base has no laws.
   A copy-on-write array of `Data` costs a slice per write (cheap at tens
   to hundreds of items) and keeps the code and the proofs about lists.

2. **Lazy `Bool.and` and `Bool.or` in JS** (`bool_call`; `js_call`;
   `js_func` in tail position; `loop_of`). A call with both arguments
   computes the second only when the first does not decide. In tail
   position it returns early, and the second argument is a tail call, so
   a recursive "any" or "all" compiles to a loop that stops at the first
   hit. Bend is pure and total, so a value nobody reads need not be
   computed: no result changes. Test: `tests/compile/
   and_or_tail_loop.bend`.

3. **Picks in JS** (`bool_pick`, `pick_call`, `pick_arm`; `js_call`;
   `js_func`; `loop_of`). A def whose body matches its first argument, a
   `Bool`, and gives one of its other arguments or a constant in each arm
   (`pick(c, a, b)`, `count_if(ok, n)`) compiles, at each full call, to an
   `if` that computes only the argument it gives; in tail position each
   branch is a tail call. This is the commonest shape of "inline a small
   def whose argument is used in only some arms". Test:
   `tests/compile/pick_tail_loop.bend`.

4. **One shared object per field-less constructor in JS** (`js_ctor`,
   `js_ctors`; `js_lib` writes them first as `const K$...`). `None{}`,
   `[]`, a tag-only enum value: one object each, not a new one at each
   use. JS never writes into a value of a Bend program, so sharing is
   the same value. (An `Array` is never a field-less constructor.)

On a program whose time goes to such calls, changes 2 to 4 cut the run
time by about a quarter to a half, and moving its hot records from
lists to `Vec` cut it by about a further 3 times. Measure your own
program before and after: the gain depends on its shape.

## Why upstream would likely refuse them

- **The size cap.** `gates/repo.ts` caps `comp.ts` at 66k tokens
  (ttok, gpt-3.5-turbo), permanently; only Taelin may change a cap, and a
  file over its cap must be made smaller "by simplification, never by
  moving code out". At the fork point `comp.ts` was at 66,000 exactly;
  with these changes it is 68,177. Anything sent upstream must first make
  room, by simplifying other code.
- **The JS lane is a reference compiler.** The maintainers send
  performance work to the C side and keep the JS output simple: issues
  #1550 and #1644 and several other JS-only pull requests were closed that
  way. JS-only operations for `bool_and` and `bool_pick` were dropped in
  review (#974, #1040, #1043; #1061 merged without them) as "global state
  for things only the JS compilation needs". Changes 2 to 4 are JS-only.
- **Strictness is a stated design.** WONTFIX: "`bend file.bend` runs a
  pure main lazily; compiled lanes are strict (#775)". Making a compiled
  lane lazier for some calls works against that line, even though it
  changes no value. A report that shows the cost as a difference between
  the lanes (as #775 did) has the best chance.
- **No common-subexpression elimination, no inference** (WONTFIX #812):
  the team prefers that the programmer restructure code. They may say the
  same of picks: "match in a helper instead".
- **`Vec` adds a type to Base.** Base holds what no library can build. A
  list with a native array behind it can only be built in the compiler
  (`OPTIMIZED`), which is an argument for it, but it is also one more
  thing the small team must keep in every lane, and the C lane does not
  benefit (it runs the list defs).
- **The repo gate itself fails here:** this file (`FORK_NOTES.md`) is not
  on `gates/repo.ts`'s allow list. That is fine in the fork; drop it from
  anything sent upstream.

Upstream has a library target for pure defs in its SOON list (#813, "a
native library target for pure defs") and an open request for a browser
library target (#1352); those are where a JS-performance discussion fits.

## Lessons learned

The JS emitter:

- A call's spine (`term_spine`) has `k === null` when its def is an
  operation (`intr_of`): `Bool.or` is the operation `bool_or`, so code
  that looks for `m.k === "Bool.or"` never sees it. Read `m.t.k` and
  `m.args` (as `bool_call` does).
- `js_func` returns `js_expr` at once when `args.length === 0 &&
  fun_live(x, ty)`; a check for a tail call must come before that line.
- A def compiles to a loop (`for (;;)` with `$0`, `$1`, ...) only if
  `loop_of` finds a self call in tail position; a new kind of tail
  position (inside `Bool.and`, inside a pick) must be taught to `loop_of`
  too, or the emitted `continue` has no loop to continue.
- Statements pushed by `js_expr` (`emit_hold`, `file_push`) land where the
  current scope is writing, so an argument emitted inside a `block` or an
  `if` is computed only there. That is all laziness needs.
- `bend file.bend -o x.js` and `-o x.mjs` share the emitter; check your
  change in the module you actually import (a benchmark script that
  writes `bench.js` does not rebuild the `app.mjs` you load elsewhere).

Writing Bend for speed:

- A match takes only a parameter or a pattern's field: a computed value
  goes to a helper def. Matches follow binder order: matching an earlier
  parameter after a later binder fails ("can't be matched in this
  position"). Defs must come before their use; no mutual recursion (a
  closure, `u => ...`, can stand in).
- The termination check reads arguments left to right: put the counter
  that shrinks first.
- A `+` (reusable) variable that is destructured and then passed on
  whole is rebuilt in JS (`{$: "Point", ...fields}`): pass it whole, or
  read fields with accessors, in hot code.
- Templates (`~f`) give loops with no closure per call; their argument
  must be closed, so pass the extra data as an argument of the template.
- `Kind` is a keyword; name a record something else.
- Measure in the browser: Bun (JSC) and Chromium (V8) rank the same code
  differently (the same program can run about twice as fast in one as in
  the other).

What did not help, so it is not tried again:

- A JS `WeakMap` cache keyed by a value object. Bend builds a new object
  at almost every update, so the table grows, and garbage collection
  costs more than the cache saves. A def of one small key (a name, an
  enum) that the host memoizes works better.
- The C lane, for allocation-heavy code (immutable lists, a new record
  at each step). It ran about 2 times slower than the same program's JS
  under V8: the cost was the data's shape, not the language.

## Rebasing and testing

The tests run on upstream's cluster of Mac minis (`gates/test.ts`), in
four lanes: check, interpreter, JS and C. Locally, in WSL:

    bun bend2/main.ts tests/compile/vec_ops.bend         # check and run
    bun bend2/main.ts tests/compile/vec_ops.bend -o t.js && bun t.js
    bun bend2/main.ts tests/compile/vec_ops.bend -o t.c
    gcc -std=gnu11 -O2 t.c -lpthread -lm -o t && ./t   # clang lacks
                                                       # headers here

The two loop tests run at 1,000 items: the interpreter lane takes about
quadratic time on them (17.8 s at 5,000), past the gate's 5 s alarm. At
200,000 items their JS ran here, where upstream's JS overflowed the host's
stack (checked by hand with upstream's `comp.ts`).

When upstream changes `comp.ts`, the fork's hunks are small and local:
the `OPERATIONS` and `OPTIMIZED` entries, the helpers before
`term_spine`, `loop_of`'s walk, the top of `js_call` and of `js_func`,
`js_tag`'s neighbours, the `Ctr` case of `js_expr`, `js_lib`'s assembly,
and the runtime's `// Vec` section.
