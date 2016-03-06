Qerl
=====

	
What is qerl
-----

Qerl is a Qiniu lib for Erlang

Qerl will:

> 1. manage file/bucket
> 2. auth the request of upload or the callback from Qiniu
> 3. calculate qetag in parallel
> 4. retry automatically (for some http status codes)
> 5. ...


Build
-----

    $ rebar3 compile

USAGE
-----
	add it as a dependency in your application
	add your ak sk in the ./include/config.hrl
	add qerl in you app.src
	qerl:start().
	

	

    
