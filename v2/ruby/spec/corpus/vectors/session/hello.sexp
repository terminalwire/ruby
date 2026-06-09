; A minimal server-role session tape: the client says hello, the server
; welcomes it, opens stdout, writes a byte payload, and exits. Reads like a
; transcript; the Sexp reader groups it into recv/emit steps.
(tape "hello-welcome-exit"
  (server)
  (recv (hello :sid 0 :protocol 2 :capabilities ("stdio")))
  (send (welcome :sid 0 :protocol 2 :capabilities ("stdio")))
  (recv (open :sid 1 :stream "stdout"))
  (send (data :sid 1 :bytes (bin "aGk=")))
  (send (close :sid 1))
  (send (exit :sid 0 :status 0)))
