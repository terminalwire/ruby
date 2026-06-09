; A client-role tape: the fake frontend processes frames the server sends and
; records its observable output (out / stdout / exit). Exercises the
; client-grouping path of the Sexp interpreter.
(tape "client-echo"
  (client :origin "ws://localhost")
  (process (welcome :sid 0 :protocol 2))
  (process (data :sid 1 :bytes (bin "aGVsbG8=")))
  (stdout "hello")
  (process (exit :sid 0 :status 0))
  (exit 0))
