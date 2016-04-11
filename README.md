Qerl
=====

	
What is qerl
-----

Qerl is a Qiniu lib for Erlang

七牛唯一提供块级并发上传  并行计算Qetag能力的SDK

Qerl will:

> 1. manage file/bucket
> 2. auth the request of upload and the callback from Qiniu
> 3. calculate qetag in parallel
> 4. upload blocks in parallel
> 5. retry automatically (for some http status codes)
> 6. ...


Build
-----

    $ rebar3 compile

USAGE
-----
	add it as a dependency in your application
	add your ak sk in the ./include/config.hrl
	add qerl in you app.src
	qerl:start().
	

	

    
