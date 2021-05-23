open Core_kernel
open Opium

open Comby_kernel
open Matchers

open Server_types

let (>>|) = Lwt.Infix.(>|=)

let certificate_file =
  match Sys.getenv "CERTIFICATE_FILE" with
  | exception Not_found -> None
  | file -> Some file

let key_file =
  match Sys.getenv "KEY_FILE" with
  | exception Not_found -> None
  | file -> Some file

let https =
  if Option.is_some certificate_file  && Option.is_some key_file then
    Some true
  else
    None

let interface =
  match Sys.getenv "INTERFACE" with
  | exception Not_found -> None
  | interface -> Some interface

let port =
  match Sys.getenv "PORT" with
  | exception Not_found -> None
  | port -> Some (Int.of_string port)

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

let with_rule rule ~(f : rule option -> string) =
  match Option.map rule ~f:Rule.create with
  | None -> 200, f None
  | Some Ok rule -> 200, f (Some rule)
  | Some Error error -> 400, Error.to_string_hum error

let with_matcher language ~f =
  match Matchers.Alpha.select_with_extension language with
  | Some matcher -> f matcher
  | None -> f (module Matchers.Alpha.Generic)

let perform_match request =
  Request.to_plain_text request
  >>| check_too_long
  >>| Result.map ~f:(fun v -> In.match_request_of_yojson @@ Yojson.Safe.from_string v)
  >>| Result.join
  >>| function
  | Error error -> Response.make ~status:(Status.of_code 400) ~body:(Body.of_string error) ()
  | Ok In.({ source; match_template; rule; language; id } as request) ->
    if debug then Format.printf "Received %s@." (Yojson.Safe.pretty_to_string (In.match_request_to_yojson request));
    with_matcher language ~f:(fun (module Matcher) ->
        let run rule =
          let configuration = Matchers.Configuration.create ~match_kind:Fuzzy () in
          let matches = Matcher.all ~configuration ~template:match_template ?rule ~source () in
          Out.Matches.to_string { matches; source; id }
        in
        let code, result = with_rule rule ~f:run in
        let headers = Headers.of_list ["Access-Control-Allow-Origin", "*"] in
        Response.make ~headers ~status:(Status.of_code code) ~body:(Body.of_string result) ())

let perform_rewrite request =
  Request.to_plain_text request
  >>| check_too_long
  >>| Result.map ~f:(fun v -> In.rewrite_request_of_yojson @@ Yojson.Safe.from_string v)
  >>| Result.join
  >>| function
  | Error error -> Response.make ~status:(Status.of_code 400) ~body:(Body.of_string error) ()
  | Ok ({ source; match_template; rewrite_template; rule; language; substitution_kind; id } as request) ->
    if debug then Format.printf "Received %s@." (Yojson.Safe.pretty_to_string (In.rewrite_request_to_yojson request));
    with_matcher language ~f:(fun (module Matcher) ->
        let source_substitution =
          match substitution_kind with
          | "newline_separated" -> None
          | "in_place" | _ -> Some source
        in
        let default =
          Out.Rewrite.to_string
            { rewritten_source = ""
            ; in_place_substitutions = []
            ; id
            }
        in
        let run rule =
          let configuration = Matchers.Configuration.create ~match_kind:Fuzzy () in
          let matches = Matcher.all ~configuration ~template:match_template ?rule ~source () in
          Comby_kernel.Matchers.Rewrite.all matches ?source:source_substitution ~rewrite_template
          |> Option.value_map ~default ~f:(fun Comby_kernel.Replacement.{ rewritten_source; in_place_substitutions } ->
              Out.Rewrite.to_string
                { rewritten_source
                ; in_place_substitutions
                ; id
                })
        in
        let code, result = with_rule rule ~f:run in
        let headers = Headers.of_list ["Access-Control-Allow-Origin", "*"] in
        Response.make ~headers ~status:(Status.of_code code) ~body:(Body.of_string result) ())

let () =
  App.empty
  |> App.post "/match" perform_match
  |> App.post "/rewrite" perform_rewrite
  |> App.run_command
