import basem, jsonm, ../../web/serverm


# action -------------------------------------------------------------------------------------------
proc action*[T](action: string, args: T, state = false): string =
  (action: "/" & action, args: args, state: state).to_json.to_s

proc action*(action: string, state = false): string =
  (action: "/" & action, state: state).to_json.to_s


# base_assets --------------------------------------------------------------------------------------
# TODO 2 use live reload ${useLiveReload ? `<script src="${assetPath('/livereload.js')}"></script>` : ''}
proc base_assets*[S, R](server: S, req: R): string = fmt"""
  <script src="{server.asset_path("/vendor/jquery-3.6.0.min.js")}"></script>
  <script src="{server.asset_path("/vendor/morphdom-2.6.1.min.js")}"></script>
  <script src="{server.asset_path("/client.build.js")}" type="module"></script>
  <link rel="stylesheet" href="{server.asset_path("/styles.css")}">
  <script>
    window.user_token    = "{req.user_token}"
    window.session_token = "{req.session_token}"
  </script>
"""