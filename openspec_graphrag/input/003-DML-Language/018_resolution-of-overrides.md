<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Resolution of overrides

This section describes in detail the rules for how DML handles when there are
multiple definitions of the same parameter or method. A less technical but
incomplete description can be found in the [section on templates](#templates).

* Each declaration in every DML file is assigned a *rank*. The set of ranks
  form a partial order, and are defined as follows:
  * The top level of each file has a rank.
  * Each template definition has a rank.
  * The block in an `in each` declaration has a rank.
  * If one object declaration has rank *R*, then any subobject
    declaration inside it, also those inside an `#if` block, has rank *R*.
  * `param` and `method` declarations has the rank of the object they
    are declared within. This includes shared methods.
  * If an object declaration contains <code>is <em>T</em></code>, then
    that object declaration has higher rank than the body of the
    template *`T`*.
  * If one file *F<sub>1</sub>* imports another file *F<sub>2</sub>*,
    then the top level of *F<sub>1</sub>* has higher rank than the top
    level of *F<sub>2</sub>*.
  * A declaration has higher rank than the block of any `in each`
    declaration it contains.
  * An `in each` block has higher rank than the templates it applies to
  * If there are three declarations *D<sub>1</sub>*, *D<sub>2</sub>*
    and *D<sub>3</sub>*, where *D<sub>1</sub>* has higher rank than
    *D<sub>2</sub>* and *D<sub>2</sub>* has higher rank than
    *D<sub>3</sub>*, then *D<sub>1</sub>* has higher rank than
    *D<sub>3</sub>*.
  * A declaration may not have higher rank than itself.
* In a set of `method` or `param` declarations that declare the same
  object in the hierarchy, then we say that one declaration
  *dominates* the set if it has higher rank than all other
  declarations in the set.  Abstract `param` declarations (<code>param
  <em>name</em>;</code> or <code>param <em>name</em> :
  <em>type</em>;</code>) and abstract method definitions (<code>method
  <em>name</em>(<em>args...</em>);</code>) are excluded here; they
  cannot dominate a set, and a dominating declaration in a set does
  not need to have higher declaration than any abstract `param` or
  `method` declaration in the set.
* There may be any number of *untyped* abstract definitions of a
  parameter (<code>param <em>name</em>;</code>).
* There may be at most one *typed* abstract definition of a parameter
  (<code>param <em>name</em> : <em>type</em>;</code>)
* There may be at most one abstract shared definition of a method. Any
  other *shared* definition of this method must have higher rank than
  the abstract definition, but any rank is permitted for non-shared
  definitions. For instance:

  ```
  template a {
      method m() default {}
  }
  template b {
      shared method m() default {}
  }
  template aa is a {
      // OK: overrides non-shared method
      shared method m();
  }
  template bb is b {
      // Error: abstract shared definition overrides non-abstract
      shared method m();
  }
  ```
* When there is a set of declarations of the same a `method` or
  `param` object in the hierarchy, then there must be (exactly) one of
  these declarations that dominates the set; it is an error if there
  is not.
* If there is a `method` or `param` that is *not* declared `default`,
  then it must dominate the set of declarations of that method or
  parameter; it is an error if it does not.
* In the above two rules, "the set of declarations" of an object does
  not include declarations that are disabled through an `#if`
  statement, or definitions that appear in a template that never is
  instantiated in an object. However, the rules *do* also apply to
  *shared* method declarations in templates, regardless whether the
  templates are used. For instance:
  ```
  template t1 {
      method a() {}
      shared method b() {}
  }
  template t2 is t1 {
      // OK, as long as t2 never is instantiated
      method a default {}
      // Error, even if t2 is unused
      shared method b() default {}
  }
  ```

* If the set of declarations *D<sub>1</sub>*, *D<sub>2</sub>*, ...,
  *D<sub>n</sub>* of a method *M* is dominated by the declaration
  *D<sub>n</sub>*, then:
  * If there is a *k*, 1 ≤ *k* ≤ n-1, such that *D<sub>k</sub>* dominates
    the set *D<sub>1</sub>*, ..., *D<sub>n-1</sub>*, then the symbol
    `default` refers to the method implementation of *D<sub>k</sub>*
    within the scope of the method implementation of *D<sub>n</sub>*.
  * If not, then `default` is an illegal value within the method
    implementation of *D<sub>n</sub>*.

It follows that:
* The following code is illegal, because it would otherwise give T a higher
  rank than itself:

  ```
  template T {
      #if (p) {
          group g is T {
              param p = false;
          }
      }
  }
  ```

* Cyclic imports are not permitted, for the same reason.
* If an object is declared twice on the top level in the same file,
  then both declarations have the same rank. Thus, the following
  declarations of the parameter `p` count as conflicting, because
  neither has a rank that dominates the other:

  ```
  bank b {
      register r {
          param p default 3;
      }
  }
  bank b {
      register r {
          param p = 4;
      }
  }
  ```

