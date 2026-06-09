; A server-role tape that drives the request/response + do-action + event +
; reject paths of the Sexp interpreter. The `do` step is a server-side action
; (not a received frame); `event` records a side effect; `reject` marks a step
; the server must refuse.
(tape "server-request-flow"
  (server)
  (recv (hello :sid 0 :protocol 2 :capabilities ("file")))
  (send (welcome :sid 0 :protocol 2 :capabilities ("file")))
  (do (grant :sid 1 :bytes 4096))
  (recv (request :sid 1 :resource "file" :method "read" :params (:path "/etc/hostname")))
  (event opened :path "/etc/hostname")
  (send (response :sid 1 :ok true :value (bin "b2s=")))
  (recv (request :sid 2 :resource "file" :method "write"))
  (reject)
  (do (close))
  (send (exit :sid 0 :status 0)))
