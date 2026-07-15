/// Shared HTTP timeout for all raw `http.*` calls across the app's service
/// layer. Render's free tier spins the backend down after inactivity, and a
/// cold start can take up to ~50s — long enough that no request should be
/// left to hang on the platform's own (much longer, silent) default socket
/// timeout. 60s comfortably covers a cold start while still surfacing a
/// clear, actionable error if the backend is genuinely unreachable.
const kApiTimeout = Duration(seconds: 60);

const kApiColdStartMessage =
    'The server is waking up (this can take up to a minute on Render\'s '
    'free tier after a period of inactivity). Please wait and try again.';
