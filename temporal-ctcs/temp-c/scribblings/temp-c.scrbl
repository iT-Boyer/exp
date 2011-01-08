#lang scribble/doc
@(require scribble/manual
          scribble/bnf
          scribble/eval
          (for-label racket/base
                     racket/contract
                     racket/match
                     racket/list))

@(define our-eval (make-base-eval))

@title{@bold{Temporal Contracts}: Explicit Contract Monitors}

@author[@author+email["Jay McCarthy" "jay@racket-lang.org"]]

@defmodule[temp-c]

The contract system implies the presence of a "monitoring system" that ensures that contracts are not violated. The @racketmodname[racket/contract] system compiles this monitoring system into checks on values that cross a contracted boundary. This module provides a facility to pass contract boundary crossing information to an explicit monitor for approval. This monitor may, for example, use state to enforce temporal constraints, such as a resource is locked before it is accessed.

@section[#:tag "monitor"]{Monitors}

@defmodule[temp-c/monitor]
@(require (for-label "../monitor.rkt"))
@interaction-eval[#:eval our-eval (require "../monitor.rkt" racket/contract racket/match)]

@deftogether[[
@defstruct*[monitor ([label symbol?]) #:transparent]
@defstruct*[(monitor:proj monitor)
            ([label symbol?] [proj-label symbol?] [v any/c])
             #:transparent]
@defstruct*[(monitor:call monitor)
            ([label symbol?] [proj-label symbol?] [f procedure?] 
             [app-label symbol?] [kws (listof keyword?)] [kw-args list?] [args list?])
            #:transparent]
@defstruct*[(monitor:return monitor)
            ([label symbol?] [proj-label symbol?] [f procedure?] 
             [app-label symbol?] [kws (listof keyword?)] [kw-args list?] [args list?]
             [rets list?])
             #:transparent]
@defproc[(monitor/c [monitor-allows? (-> monitor? boolean?)]
                    [label symbol?]
                    [c contract?])
         contract?]
]]{
  
  @racket[monitor/c] creates a new contract around @racket[c] that uses @racket[monitor-allows?] to approve
  contract boundary crossings. (@racket[c] approves positive crossings first.)
  
  Whenever a value @racket[v] is projected by the result of @racket[monitor/c], @racket[monitor-allows?]
  must approve a @racket[(monitor:proj label proj-label v)] structure, where @racket[proj-label] is a unique
  symbol for this projection.
  
  If @racket[monitor-allows?] approves and the value is not a function, then the value is returned.
  
  If the value is a function, then a projection is returned, whenever it is called, @racket[monitor-allows?]
  must approve a @racket[(monitor:call label proj-label v app-label kws kw-args args)] structure,
  where @racket[app-label] is a unique symbol for this application and @racket[kws], @racket[kw-args], @racket[args]
  are the arguments passed to the function.
  
  Whenever it returns, @racket[monitor-allows?]
  must approve a @racket[(monitor:return label proj-label v app-label kws kw-args args rets)] structure,
  where @racket[ret] are the return values of the application.
  
  The unique projection label allows explicitly monitored contracts to be useful when used in a first-class way 
  at different boundaries.
  
  The unique application label allows explicitly monitored contracts to pair calls and returns when functions
  return multiple times or never through the use of continuations.
  
}
  
Here is a short example that uses an explicit monitor to ensure that @racket[_malloc] and @racket[_free] are
used correctly.
@racketblock[
 (define allocated (make-weak-hasheq))
 (define memmon
   (match-lambda
     [(monitor:return 'malloc _ _ _ _ _ _ (list addr))
      (hash-set! allocated addr #t)
      #t]
     [(monitor:call 'free _ _  _ _ _ (list addr))
      (hash-has-key? allocated addr)]
     [(monitor:return 'free _ _ _ _ _ (list addr) _)
      (hash-remove! allocated addr)
      #t]
     [_
      #t]))
 (provide/contract
  [malloc (monitor/c memmon 'malloc (-> number?))]
  [free (monitor/c memmon 'free (-> number? void))])
]
           
@section[#:tag "dsl"]{Domain Specific Language}

@defmodule[temp-c/dsl]
@(require (for-label racket/match
                     racket/contract
                     "../dsl.rkt"
                     "../../automata/re.rkt"
                     "../../automata/re-ext.rkt"))
@interaction-eval[#:eval our-eval (require "../dsl.rkt")]

Constructing explicit monitors using only @racket[monitor/c] can be a bit onerous. This module provides some helpful tools for making the definition easier. It provides everything from @racketmodname[temp-c/monitor], as well as all bindings from @racketmodname[automata/re] and @racketmodname[automata/re-ext]. The latter provide a DSL for writing "dependent" regular expression machines over arbitrary @racketmodname[racket/match] patterns.

First, a few @racket[match] patterns are available to avoid specify all the details of monitored events (since most of the time the detailed options are unnecessary.)

@defform[(call n a ...)]{ A @racket[match] expander for call events to the labeled function @racket[n] with arguments @racket[a]. }
@defform[(ret n a ...)]{ A @racket[match] expander for return events to the labeled function @racket[n] with return values @racket[a]. }

@defform[(with-monitor contract-expr re-expr)]{ Defines a monitored contract where the structural portion of the contract is the @racket[contract-expr] (which may included embedded @racket[label] expressions) and where the temporal portion of the contract is the regular expression given by @racket[re-expr]. }

@defform[(label id contract-expr)]{ Labels a portion of a structural contract inside of @racket[with-monitor] with the label @racket[id]. }

Here is a short example for @racket[_malloc] and @racket[_free]:
@racketblock[
(with-monitor 
    (cons/c (label 'malloc (-> addr?))
            (label 'free (-> addr? void?)))
  (complement 
   (seq (star _)
        (dseq (call 'free addr)
              (seq
               (star (not (ret 'malloc (== addr))))
               (call 'free (== addr)))))))
]