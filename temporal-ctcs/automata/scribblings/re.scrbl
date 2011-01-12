#lang scribble/doc
@(require scribble/manual
          scribble/bnf
          scribble/eval
          (for-label racket/base
                     racket/function
                     racket/contract
                     racket/list))

@(define our-eval (make-base-eval))

@title[#:tag "re"]{Regular Expressions}

@defmodule[automata/re]
@(require (for-label "../re.rkt"
                     "../machine.rkt"))
@interaction-eval[#:eval our-eval (require "../re.rkt")]

This module provides a macro for regular expression compilation.

@defform/subs[#:literals (complement seq union star epsilon nullset dseq)
                         (re re-pat)
                         ([re-pat (complement re-pat)
                                  (seq re-pat ...)
                                  (union re-pat ...)
                                  (star re-pat)
                                  epsilon
                                  nullset
                                  re-transformer
                                  (re-transformer . datum)
                                  (dseq pat re-pat)
                                  pat])]{
 Compiles a regular expression over match patterns to a @racket[machine].
                                                        
 The interpretation of the pattern language is mostly intuitive. The pattern language may be extended
 with @racket[define-re-transformer]. @racket[dseq] allows bindings of the @racket[match] pattern to be
 used in the rest of the regular expression. (Thus, they are not @emph{really} regular expressions.)
 
 The compiler will use an NFA, provided @racket[complement] and @racket[dseq] are not used. Otherwise, 
 many NFAs connected with the machine simulation functions from @racketmodname[automata/machine] are used.
}
 
@(define-syntax-rule (defidforms (id ...) . dat)
   (deftogether ((defidform id) ...) . dat))
                                        
@defidforms[(complement seq union star epsilon nullset dseq)]{
 Bindings for use in @racket[re]. 
}

@defform[(define-re-transformer id expr)]{
 Binds @racket[id] as an regular expression transformer used by the @racket[re] macro. The expression should evaluate to a function that accepts a syntax object and returns a syntax object that uses the regular expression pattern language.
}

@section[#:tag "re-ext"]{Extensions}

@defmodule[automata/re-ext]
@(require (for-label "../re-ext.rkt"))
@interaction-eval[#:eval our-eval (require "../re-ext.rkt")]

This module provides a few transformers that extend the syntax of regular expression patterns.

@defform[(opt re-pat)]{ Optionally matches @racket[re-pat]. }
@defform[(plus re-pat)]{ Matches one or more @racket[re-pat] in sequence. }
@defform[(rep re-pat num)]{ Matches @racket[re-pat] in sequence @racket[num] times, where @racket[num] must be syntactically a number. }
@defform[(difference re-pat_0 re-pat_1)]{ Matches everything that @racket[re-pat_0] does, except what @racket[re-pat_1] matches. }
@defform[(intersection re-pat_0 re-pat_1)]{ Matches the intersection of @racket[re-pat_0] and @racket[re-pat_1]. }

@section[#:tag "re-ex"]{Examples}

@interaction-eval[#:eval our-eval (require "../machine.rkt" racket/function)]

@defexamples[
#:eval our-eval
(define-syntax-rule (test-re R (succ ...) (fail ...))
  (let ([r (re R)])
    (printf "Success: ~v => ~v\n" succ (machine-accepts? r succ))
    ...
    (printf "Failure: ~v => ~v\n" fail (machine-accepts? r fail))
    ...))
(test-re epsilon
          [(list)]
          [(list 0)])
 
 (test-re nullset
          []
          [(list) (list 1)])
 
 (test-re "A"
          [(list "A")]
          [(list)
           (list "B")])
 
 (test-re (complement "A")
          [(list)
           (list "B")
           (list "A" "A")]
          [(list "A")])
 
 (test-re (union 0 1)
          [(list 1)
           (list 0)]
          [(list)
           (list 0 1)
           (list 0 1 1)])
 
 (test-re (seq 0 1)
          [(list 0 1)]
          [(list)
           (list 0)
           (list 0 1 1)])
 
 (test-re (star 0)
          [(list)
           (list 0)
           (list 0 0)]
          [(list 1)])
 
 (test-re (opt "A")
          [(list)
           (list "A")]
          [(list "B")])
 
 (define-re-transformer my-opt
  (syntax-rules ()
    [(_ pat)
     (union epsilon pat)]))
 
 (test-re (my-opt "A")
          [(list)
           (list "A")]
          [(list "B")])
 
 (test-re (plus "A")
          [(list "A")
           (list "A" "A")]
          [(list)])
 
 (test-re (rep "A" 3)
          [(list "A" "A" "A")]
          [(list)
           (list "A")
           (list "A" "A")])
 
 (test-re (difference (? even?) 2)
          [(list 4)
           (list 6)]
          [(list 3)
           (list 2)])
 
 (test-re (intersection (? even?) 2)
          [(list 2)]
          [(list 1)
           (list 4)])
 
 (test-re (complement (seq "A" (opt "B")))
          [(list "A" "B" "C")]
          [(list "A")
           (list "A" "B")])
 
 (test-re (seq epsilon 1)
          [(list 1)]
          [(list 0)
           (list)])
 
 (test-re (seq 1 epsilon)
          [(list 1)]
          [(list 0)
           (list)])
 
 (test-re (seq epsilon
               (union (seq (star 1) (star (seq 0 (star 1) 0 (star 1))))
                      (seq (star 0) (star (seq 1 (star 0) 1 (star 0)))))
               epsilon)
          [(list 1 0 1 0 1)
           (list 0 1 0 1 0)
           (list 1 0 1 1 0 1)
           (list 0 1 0 0 1 0)
           (list)]
          [(list 1 0)])
 
 (test-re (star (complement 1))
          [(list 0 2 3 4)
           (list)
           (list 2)
           (list 234 5 9 1 9 0)
           (list 1 0)
           (list 0 1)]
          [(list 1)])
 
 (test-re (dseq x (? (curry equal? x)))
          [(list 0 0)
           (list 1 1)]
          [(list)
           (list 1)
           (list 1 0)])]
