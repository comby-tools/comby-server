open Core_kernel
open Dream
open Lwt

open Comby_kernel
open Matchers

open Server_types

let (>>|) = (>|=)


let debug =
  match Sys.getenv "DEBUG" with
  | exception Not_found -> false
  | _ -> true

let max_request_length =
  match Sys.getenv "MAX_REQUEST_LENGTH" with
  | exception Not_found -> Int.max_value
  | v -> Int.of_string v

let check_too_long s =
  let n = String.length s in
  if n > max_request_length then
    Error
      (Format.sprintf
         "The source input is a bit big! Make it %d characters shorter, \
          or click 'Run in Terminal' below to install and run comby locally :)"
         (n - max_request_length))
  else
    Ok s

let perform_match request =
  Dream.body request
  >>| check_too_long
  >>| Result.map ~f:(fun v -> In.match_request_of_yojson @@ Yojson.Safe.from_string v)
  >>| Result.join
  >>| function
  | Ok In.({ source; match_template; rule; language; id } as request) ->
    if debug then Format.printf "Received %s@." (Yojson.Safe.pretty_to_string (In.match_request_to_yojson request));
    let matcher =
      match Matchers.Alpha.select_with_extension language with
      | Some matcher -> matcher
      | None -> (module Matchers.Alpha.Generic)
    in
    let run ?rule () =
      let configuration = Matchers.Configuration.create ~match_kind:Fuzzy () in
      let specification = Specification.create ~match_template ?rule () in (* TODO: rewrite this part *)
      let matches =
        Pipeline.execute
          matcher
          ~configuration
          (String source)
          specification
        |> function
        | Matches (m, _) -> m
        | _ -> []
      in
      Out.Matches.to_string { matches; source; id }
    in
    let code, result =
      match Option.map rule ~f:Rule.create with
      | None -> 200, run ()
      | Some Ok rule -> 200, run ~rule ()
      | Some Error error -> 400, Error.to_string_hum error
    in
    Dream.respond ~code result
  | Error error ->
    Dream.respond ~code:400 error


let () =
  Dream.run
  @@ Dream.router
    [ Dream.post "/match" perform_match
      (*
            ; Dream.post "/rewrite" perform_rewrite
            ; Dream.post "/substitute" perform_environment_substitute
      *)
    ]
  @@ Dream.not_found
