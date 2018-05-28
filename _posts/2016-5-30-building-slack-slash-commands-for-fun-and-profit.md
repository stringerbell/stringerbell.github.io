---
layout: post
---

I’ve been recently learning about and using [expressive](https://docs.zendframework.com/zend-expressive/), a microframework made in PHP that uses [PSR-7](https://github.com/php-fig/fig-standards/blob/master/accepted/PSR-7-http-message.md).

In this post, I’d like to walk through how I made the `/jira` Slack slash command at my job. If you want to follow along, you can [check out the repo here](https://github.com/stringerbell/expressive-demo-jira-slack), and then run `composer install` to get all the dependencies installed. Also, I’m using PHP 7, so be sure to have that running if you’d like to run these examples. Mainly, I’m using the ultra awesome `??` null coalesce operator, which makes so many things so much easier and cleaner and more fun to write. [Read up on it here if you don’t know about it already.](https://wiki.php.net/rfc/isset_ternary)

It’s been a lot of fun to make some tools for my team to help improve their workflows, and automate a lot of tedious tasks using it.

If you’re not already familiar with Slack slash commands, here’s how they work:

You run `/$command [ args ]`, inside of Slack and Slack will send a request to an endpoint of your choosing, and you can respond, and do whatever work you need.

Here’s a partial list of what I’ve been able to make using slash commands.

{% highlight diff %}
 /jenkins [run] [jobName] [ options ]
 -p|--public publicly post option
 -s|--status get job statuses
 -l|--last <integer> get last n jobs
 -f|--filter <string> regex filter jobs
{% endhighlight %}
For `/jenkins`, it’s really handy to be able to see the status of the last $n jobs, or kick off a particular job. It’s also really handy to do this while eating lunch, or wherever you find yourself away from your terminal and/or not connected to your VPN that can talk to [Jenkins](https://jenkins.io/).

```/rebase [featureBranch] [repo]```

`/rebase` is used in our current workflow to rebase your work on top of master. For us, we like to have our Pull Requests exactly 1 commit ahead, and 0 behind `master`, so when we’re ready to merge, our history looks nice and tidy, and `git bisect` is easy to use. Having this in Slack might seem like overkill, but it’s particularly awesome when:

- You’re in the middle of something else, and your PR is ready to be merged.
- There’s a one or more PR’s ahead of yours, and after merging them (we use the `--no-ff` option), your PR is behind.
We also have an endpoint set up that notifies the author on Slack when their PR has enough peer reviewed approvals, but isn’t 1 commit ahead and 0 behind. Slack will include the `/rebase` command right in the message so the author is able to copy paste the command right back into Slack and everything gets taken care of automagically. Boom. Hooray automation!

{% highlight diff %}
 /mailgun [sync|add|get|forward] [ options ]
 -p|--public publicly post option
 -v|--valid? check to see if mailgun has valid records when using `get` command
 -f|--from <string> from address when using `forward` command
 -t|--to <string> to address when using `forward` command
 -l|--list list routes for `forward` command
 --filter <string> regex filter for routes when using `forward` command
{% endhighlight %}
`/mailgun` makes calls using the mailgun API. It’s pretty self explanatory, but being able to do things without logging into mailgun is a productivity booster.

{% highlight diff %}
 /twilio accountname search|show_errors sms|voice [ options ]
 -p|--public publicly post option
 -f|--from <string> filter by from number when using `search`
 -t|--to <string> filter by to number when using `search`
 --sid <string> filter by SID when using `search`
 --status <string> filter by call status for `voice` when using `search`
 -s|--start <string> filter by voice|sms started after midnight on a date
 -e|--end <string> filter by voice|sms started before midnight on a date
 -c|--code <string> search for error code(s) (separated by spaces) when using `show_errors`
 --error <string> regex search for twilio error message `show_errors`
 -l|--limit <integer> limit results when using `search` or `show_errors
{% endhighlight %}
`/twilio` is useful for easily troubleshooting and querying twilio. Also super nice to not have to login and check on an error when you’re able to do it right from the comfort of Slack.

{% highlight diff %}
 /jira show issuesKey(s)[] [ options ]
 -p|--public publicly post option
{% endhighlight %}
`/jira` was made out of the idea that it’s really nice to be able to reference JIRA issues using their issue key in Slack without having to build or grab a link. It shows a nice summary, and can show multiple issues.

In this post, I’ll be showing you how I made `/jira` using expressive, and PHP 7. You can check out the [repo here](https://github.com/stringerbell/expressive-demo-jira-slack)

# **Set up**
I’m using composer, so if you want to follow along, run `composer self-update` if you haven’t in a while. Then run `composer create-project zendframework/zend-expressive-skeleton $projectDir` where `$projectDir` is where you'd like this project to live.

The [Zend Expressive Skeleton](https://github.com/zendframework/zend-expressive-skeleton) gives you a lot of things for free. It’s probably a bit overkill for what we need to do, but it makes things a little more magical (in a nice way), and gets you up and going really quickly, especially if you’re not already familiar with expressive.

It gives you a CLI interface to pick which router, dependency injection container, templating engine, and error handler you want to use. One interesting thing about expressive is most things are swappable, so if you decide at some point you need or want a different way to route things, it’s relatively easy to drop something else in without too much pain.

In my opinion, the biggest strength of expressive is through the convention of creating middleware pieces that look something like this:

{% highlight php linenos %}
<?php

namespace App\MiddlewareExample

/* use statements */

class MiddlewareExample
{
    public function __invoke(ServerRequestInterface $request, ResponseInterface $response, callable $next = null)
     {
         // do something interesting
         return $next($requst, $response, $error ?? null);
     }
 }
{% endhighlight %}

The above way of doing things makes it possible to build really small bits of functionality that are really easy to reason about, and test. Building things in this way has felt like building with LEGOs, which is super fun.

# **Config**
Some of the boilerplate code is already in place for you when you use the skeleton. Some of the important bits are:

- `/config/autoload/**` This is where your config files go. Expressive will autoload things for you in there, and you can fetch them like this: `$container->get('config');` Something that’s nice is that `*.local.php` is ignored by git, so it’s a good place to keep secrets, like tokens, and credentials, or local configuration that will override your `*.global.php` config files with the same name.
In the `config/autoload` directory, you’ll find:

`routes.global.php` This is where you set up your application routes.
{% highlight php linenos %}
<?php
/* ... other config */ 
'routes' =>
    [
        'name' => 'routeName',
        'path' => '/path/you/care/about',
        'middleware' => [MiddlewareStack::class], // this can be a single item, or an array of middleware classes or a middleware pipelines
        'allowed_methods' => ['GET'], // HTTP methods you want to accept
    ],
{% endhighlight %}
- `middleware-pipeline.global.php`
Also an array of configuration. There are lots of comments in that file to help understand which section does what.

- `dependencies.global.php`
This is where you register your classes, and tell expressive if they need a factory or if they can be invoked without any dependencies.

These commands are provided by using the skeleton app.

- `composer cs` (phpcs)
- `composer cs-fix` (phpcbf)
- `composer test` (phpunit)

# **First steps**
The first thing I did after setting up the skeleton is replace the `HomePageAction` `HTMLResponse` with a `JSONReponse` [changeset 6b21dd here](https://github.com/stringerbell/expressive-demo-jira-slack/commit/6b21dd5c88c06a3f6eed5bf2cfcdacb8762e4b49)

The reason you can get to it, and it works the way it does is because of `routes.global.php`

{% highlight php linenos %}
<?php

'routes' => [
    [
        'name' => 'home',
        'path' => '/',
        'middleware' => App\Action\HomePageAction::class,
        'allowed_methods' => ['GET'],
    ],
{% endhighlight %}
The next thing I did was add a Slack Jira Pipeline. [changeset cd6bda](https://github.com/stringerbell/expressive-demo-jira-slack/commit/cd6bda555a4546306bbc7754f0d3a8229799b811) All you need is to add the route you want, and register it with expressive.

{% highlight diff %}
// routes.global.php
+ [
+ 'name' => '/slack_jira',
+ 'path' => '/slack_jira',
+ 'middleware' => [SlackJiraPipeline::class],
+ 'allowed_methods' => ['POST'],
+ ],
{% endhighlight %}

{% highlight diff %}
// dependencies.global.php

'factories'  => [
    Application::class       => ApplicationFactory::class,
    Helper\UrlHelper::class  => Helper\UrlHelperFactory::class,
+ SlackJiraPipeline::class => SlackJiraPipeline::class,
{% endhighlight %}
All that pipeline looks like is this:

{% highlight php linenos %}
<?php

namespace App\Pipeline;

use App\Validator\ValidateBody;
use Interop\Container\ContainerInterface;
use Zend\Stratigility\MiddlewarePipe;

class SlackJiraPipeline
 {
     public function __invoke(ContainerInterface $container)
     {
         $pipeline = new MiddlewarePipe();
         $pipeline->pipe($container->get(ValidateBody::class));
 
         return $pipeline;
     }
 }
{% endhighlight %}
That tells expressive to route through your pipeline in the order you define. Really straightforward so far. The only piece of middleware currently in this pipeline is one we’ll create called `ValidateBody`.

All it does is make sure an incoming request with a body is valid. One bit of setup you have to do is add `BodyParamsMiddleware` to `middleware-pipeline.global.php`. This middleware comes with expressive, and allows you to call `$request->getParsedBody()`, and return an associative array with the body contents, which we’ll need for our `ValidateBody` middleware. You can also add strategies to this to parse your incoming bodies however makes the most sense for your application (strategies could be XML, or something else you're expecting to consume).

Also, putting it in `middleware-pipeline.global.php` makes it always run this to make it available everywhere instead of having to make sure it’s on every middleware stack

{% highlight diff %}

'routing' => [
             'middleware' => [
                 ApplicationFactory::ROUTING_MIDDLEWARE,
                 Helper\UrlHelperMiddleware::class,
+ Helper\BodyParams\BodyParamsMiddleware::class,
{% endhighlight %}
Onto the middleware we want to build. Here’s all ValidateBody does:

{% highlight php linenos %}
<?php

class ValidateBody
{
    public function __invoke(ServerRequestInterface $request, ResponseInterface $response, callable $next)
    {
        $body = $request->getParsedBody();
        if (!$body) {
            throw new InvalidArgumentException("Invalid Body");
        }
        return $next($request, $response);
    }
}
{% endhighlight %}
It calls `$request->getParsedBody()`, and if it’s empty, we’ll throw. That’s it! This pattern is going to become very familiar.

Throwing in a middleware will kick the request out to your error handler. That way we can cut the request short at any step if we don’t want to continue for whatever reason.

After setting that class up, we’ll need to register it with expressive in `dependencies.global.php`

{% highlight diff linenos %}
'invokables' => [
             // Fully\Qualified\InterfaceName::class => Fully\Qualified\ClassName::class,
             Helper\ServerUrlHelper::class => Helper\ServerUrlHelper::class,
+ ValidateBody::class => ValidateBody::class,
{% endhighlight %}
This tells expressive that when it’s autoloading it, since it’s in the invokables section that it can start using it right away without fetching any dependencies.

# **Testing middleware**
To give you a basic example of how to write a middleware test, I went ahead and added a couple of tests in my tests directory for the Validate body middleware [f66c9e changeset](https://github.com/stringerbell/expressive-demo-jira-slack/commit/f66c9e316f1069b16b0b866b44fbad28d9d3adf1). (also something expressive skeleton gets you set up with)

{% highlight php linenos %}
<?php

namespace AppTest\Validator;

use App\Validator\ValidateBody;
use Psr\Http\Message\ServerRequestInterface;
use Zend\Expressive\Container\Exception\InvalidArgumentException;
use Zend\Stratigility\Http\ResponseInterface;

 class ValidateBodyTest extends \PHPUnit_Framework_TestCase
 {
     private $validateBody;
 
     public function setUp()
     {
         $this->validateBody = new ValidateBody();
     }
 
     /**
      * @test
      * * @expectedException InvalidArgumentException
      */
     public function itWillThrowAnExceptionWhenBodyIsInvalid()
     {
         /** @var ServerRequestInterface $request */
         $request = $this->prophesize(ServerRequestInterface::class);
         /** @var ResponseInterface $response */
         $response = $this->prophesize(ResponseInterface::class);
         $next     = function ($request, $response) {
             return $response;
         };
         $request->getParsedBody()->shouldBeCalled()->willReturn([]);
         $result   = $this->validateBody->__invoke($request->reveal(), $response->reveal(), $next);
     }
 
     /**
      * @test
      */
     public function itWillNotThrowAnExceptionForValidBody()
     {
         /** @var ServerRequestInterface $request */
         $request = $this->prophesize(ServerRequestInterface::class);
         /** @var ResponseInterface $response */
         $response = $this->prophesize(ResponseInterface::class);
         $next     = function ($request, $response) {
             return $response;
         };
         $request->getParsedBody()->shouldBeCalled()->willReturn(["foo" => "bar"]);
         $result = $this->validateBody->__invoke($request->reveal(), $response->reveal(), $next);
         $this->assertInstanceOf(ResponseInterface::class, $result);
     }
 }
{% endhighlight %}

We’re testing both code paths. A request with a invalid body, and one with a valid body.

# **Next Steps**
We’re going to want to validate the incoming request is actually coming from Slack. We’ll do this by building a middleware piece that checks the request body’s token. [68f455 changeset](https://github.com/stringerbell/expressive-demo-jira-slack/commit/68f455995850b7afd6456b0245a1aed46aadf9aa)

In `SlackJiraPipeline.php`, we add our Slack Validate token middleware after the ValidateBody middleware

{% highlight diff %}
{
         $pipeline = new MiddlewarePipe();
         $pipeline->pipe($container->get(ValidateBody::class));
+ $pipeline->pipe($container->get(ValidateSlackToken::class));
 
         return $pipeline;
 }    
{% endhighlight %}     
Here’s `ValidateSlackToken.php`

{% highlight php linenos %}
<?php

namespace App\Validator\Slack;

use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Zend\Expressive\Container\Exception\InvalidArgumentException;

class ValidateSlackToken
 {
     /** * @var array */
     private $validTokens;
 
     public function __construct(array $validTokens)
     {
         $this->validTokens = $validTokens;
     }
 
     public function __invoke(ServerRequestInterface $request, ResponseInterface $response, callable $next)
     {
         $body  = $request->getParsedBody();
         $token = $body['token'] ?? "";
         if ($this->validTokens[$request->getUri()->getPath()] != $token) {
             throw new InvalidArgumentException("Invalid Slack Token");
         }
 
         return $next($request, $response, $error ?? null);
     }
 }
{% endhighlight %}
All it’s doing is getting the parsed body from the request, (which we **know** is valid, because of `ValidateBody`), and then getting the token from the request (where Slack puts it), and checks it against valid slack tokens. If there’s a match, we continue onto the next middleware piece, and if not, we throw.

This class has a dependency, which is `$this->validTokens`, which is an array of key values that look something like this:

{% highlight php linenos %}
<?php

[
    '/route1' => 'slackToken',
    '/route2' => 'anotherSlackToken',
]
{% endhighlight %}

The reason why we’re injecting all possible valid tokens into this class will become clear later. What it allows is for our factory to remain stateless. This ends up making life much easier down the road for numerous reason. (more on that later)

When we have a class with dependencies, we’ll need to tell expressive to instantiate it by using a factory. `ValidateSlackTokenFactory.php` in this case

{% highlight php linenos %}
<?php

namespace App\Validator\Slack;

use Interop\Container\ContainerInterface;

class ValidateSlackTokenFactory
{
    public function __invoke(ContainerInterface $container)
     {
         $validTokens = $container->get('config')['slack_config']['tokens'] ?? [];
 
         return new ValidateSlackToken($validTokens);
     }
 }
{% endhighlight %}
Here, we’re getting the entire config array (autoloaded by expressive), and then narrowing our focus to just `slack_config`, and then to `tokens`.

In tandem with the factory, we’ll need a config file that looks like this:

{% highlight php linenos %}
<?php

return [
    'slack_config' => [
        'tokens' => [
            '/slack_jira' => 'token',
            // other routes => tokens would go here
        ],
    ],
 ];
{% endhighlight %}
Here, we’re defining our route from before, and then our valid Slack token. In `ValidateSlackTokenFactory`, `$validTokens` ends up being `['/slack_jira' => 'token']`, which gets handed to our `ValidateSlackToken` middleware constructor.

To show you what a typical factory tests looks like, there’s `ValidateSlackTokenFactoryTest.php`.

{% highlight php linenos %}
<?php

namespace AppTest\Validator\Slack;

use App\Validator\Slack\ValidateSlackToken;
use App\Validator\Slack\ValidateSlackTokenFactory;
use Interop\Container\ContainerInterface;

class ValidateSlackTokenFactoryTest extends \PHPUnit_Framework_TestCase
 {
     /**
      * @test
      */
     public function itWillDoTheNeedful()
     {
         $container = $this->prophesize(ContainerInterface::class);
         $factory   = new ValidateSlackTokenFactory();
         $container->get('config')->shouldBeCalled()->willReturn([]);
         $result = $factory($container->reveal());
         $this->assertInstanceOf(ValidateSlackToken::class, $result);
     }
 }
{% endhighlight %}

We’re making a new factory, making sure that `$container->get('config')` gets called, and then asserting on the output of the factory, which should be an instance of our middleware.

[You can see another typical middleware tests for the ValidateSlackToken middleware here.](https://github.com/stringerbell/expressive-demo-jira-slack/blob/68f455995850b7afd6456b0245a1aed46aadf9aa/test/AppTest/Validator/Slack/ValidateSlackTokenTest.php)

In the interest of brevity (ha!), I’ve omitted tests for the rest of this post. Hopefully it’s clear what’s happening in the above tests so it’s really clear how to write other middleware tests.

Also, along with all of this, if you want to set up your very own slack slash command, go to `https://$slackInstance.slack.com/apps/manage/custom-integrations` Here’s a couple of screenshots of what my setup looks like.

![]({{ "https://i.imgur.com/nQ4bRbl.png" }})

![]({{ "https://i.imgur.com/46SOClF.png" }})

As an aside, if you don’t know about [ngrok](https://ngrok.com/), you should be using it. It lets you send real traffic to your localhost, which comes in especially handy when testing stuff like this.

# **More Packages, and a Parser**
Next, I added guzzle by running `composer require guzzlehttp/guzzle` [changeset 04642f](https://github.com/stringerbell/expressive-demo-jira-slack/commit/04642f83de2bd41fed4aea8f3cfa36543c50249c) Guzzle is awesome, and will come in handy when we need to start making requests from our app. After that’s finished, I ran `composer require zendframework/zend-console` [changeset bcea1d](https://github.com/stringerbell/expressive-demo-jira-slack/commit/bcea1da8dc0794df5743b636c3379fc282321202) which is used below to parse incoming input from Slack.

We need something to parse the input incoming from slack. I initially made something that worked decently, but ultimately wound up with a more formal parser I found on stack overflow. [changeset 2ebf40](https://github.com/stringerbell/expressive-demo-jira-slack/commit/2ebf40ba2a853c4d9472059e7b5eeda67c2ab4b7)

To actually start using the parser, I stuck it in a piece of middleware, along with a Slack Client piece of middleware we can use to send messages back to the Slack user. [changeset 12beab](https://github.com/stringerbell/expressive-demo-jira-slack/commit/12beab35c3f5cbe67d28c77be4d77bcc82683071)

Our slack client is a wrapper around the basic Guzzle client, with a header added to make it a little easier to use:

{% highlight php linenos %}
<?php

namespace App\Client;

use GuzzleHttp\Client;
use Interop\Container\ContainerInterface;

class SlackClient
{
     public function __invoke(ContainerInterface $container)
     {
         return new Client(['headers' => ['Content-Type' => 'application/json']]);
     }
 }
{% endhighlight %}
It follows the factory pattern in expressive, so we need to register it as such in `dependencies.global.php`

{% highlight diff %}

'factories'  => [
+ SlackClient::class => SlackClient::class,
{% endhighlight %}
In `SlackJiraPipeline.php`, we’ll add our middleware that will handle and parse the input incoming from Slack.

{% highlight diff%}
$pipeline = new MiddlewarePipe();
$pipeline->pipe($container->get(ValidateBody::class));
$pipeline->pipe($container->get(ValidateSlackToken::class));
+$pipeline->pipe($container->get(ParseSlackJiraInput::class));
{% endhighlight %}
Here’s what `ParseSlackJiraInput.php` looks like
{% highlight php linenos %}
<?php

namespace App\Validator\Slack;

use App\Utility\ArgvParser;
use GuzzleHttp\Client;
use Psr\Http\Message\ServerRequestInterface;
use Zend\Console\Exception\RuntimeException;
use Zend\Console\Getopt;
use Zend\Stratigility\Http\ResponseInterface;
 
 class ParseSlackJiraInput
 {
     /**
      * @var Client
      */
     private $slackClient;
 
     public function __construct(Client $slackClient)
     {
         $this->slackClient = $slackClient;
     }
 
     public function __invoke(ServerRequestInterface $request, ResponseInterface $response, callable $next)
     {
         $body    = $request->getParsedBody();
         $text    = $body['text'] ?? '';
         $args    = ArgvParser::parseString($text);
         $_SERVER['argv'][0] = "/jira show issuesKey(s)[]"; // will show up as usage message
         // you have to set register_argc_argv => On for this to work with Getopt, or you can dump things into $_SERVER['argv']
         $opts = new Getopt(
             [
                 'p|public' => 'publicly post option',
             ],
             $args
         );
         try {
             if (!$opts->getOptions() && count($opts->getArguments()) == 1) {
                 throw new RuntimeException("Invalid arguments", $opts->getUsageMessage());
             }
             if (!$opts->getRemainingArgs()) {
                 throw new RuntimeException("Invalid arguments", $opts->getUsageMessage());
             }
             $body['args'] = $opts->getRemainingArgs();
             // set options in body for later
             $body['response_type'] = $opts->public ? 'in_channel' : 'ephemeral';
         } catch (RuntimeException $e) {
             $responseBody = [
                 'text' => "Tried running: `{$body['command']} {$body['text']}` \n" . $e->getUsageMessage(),
             ];
             $this->slackClient->post(
                 $body['response_url'] ?? '',
                 [
                     'body'    => json_encode($responseBody),
                     'headers' => [
                         'Content-Type' => 'application/json',
                     ],
                 ]
             );
 
             $error = $e->getUsageMessage();
         }
 
         return $next($request->withParsedBody($body), $response, $error ?? null);
     }
 }
{% endhighlight %}
We’ll get the parsed (validated) body, and pull out the text portion, and hand it off to our parser. The parser will split each value into elements in an array, and then hand it back to `Getopt`, which is from Zend Console.

This makes it easy to do stuff like `$arg -o value`, and then pull out the `-o` value by doing something like `$result->o`

The above parser only accepts one option `-p` (making the results public, meaning it’ll post publicly, or default to ‘ephemeral’, meaning only the user who ran the slash command can see the results) Using the above pattern makes it trivial to add more functionality and options.

I’ve found it helpful while building slash commands to echo out the command the user put in. It makes it clearer to the user if something doesn’t work, and is handy for sharing. We’re checking to make sure the user has more than one argument in their command, (meaning they can’t successfully run something like `/jira show`) and if not, we’re posting back to the user in slack the usage.

Another benefit of doing it this way is so when new functionality gets added, or if someone is unfamiliar with options in this slash command, they can run `/jira` and get back usage info.

If you notice on line 64, we’re calling `$next` with `$request->withParsedBody($body)`. This is so we can pass things into the request and use them later on.

# **Making a request to JIRA**
[changeset 739757](https://github.com/stringerbell/expressive-demo-jira-slack/commit/73975764f41ca38a8561e915f54145f80535f557)

Now we’re finally at a point that we can query the JIRA API, and show an issue. Here’s what the relevant parts of `JiraShowIssueCommand.php` look like:

{% highlight php linenos %}
<?php

namespace App\Service\Jira;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\ClientException;
use GuzzleHttp\UriTemplate;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
 
 class JiraShowIssueCommand
 {
     /** * @var Client */
     private $jiraClient;
     /** * @var Client */
     private $slackClient;
     /** * @var string */
     private $jiraUrl;
 
     public function __construct(Client $jiraClient, Client $slackClient, string $jiraUrl)
     {
         $this->jiraClient  = $jiraClient;
         $this->slackClient = $slackClient;
         $this->jiraUrl     = $jiraUrl;
     }
 
     public function __invoke(ServerRequestInterface $request, ResponseInterface $response, callable $next)
     {
         $body = $request->getParsedBody();
         if ($body['args'][0] !== "show") {
             return $next($request, $response);
         }
         $jobs        = array_reverse(array_slice($body['args'], 1));
         $uriTemplate = new UriTemplate();
         $uri         = $uriTemplate->expand(
             'rest/api/2/search?jql=key in ({issueKeys*})&expand=editmeta&fields=customfield_10024&fields=summary'
             . '&fields=creator&fields=assignee&fields=issuetype&fields=priority&fields=status&fields=resolution',
             [
                 'issueKeys' => $jobs,
             ]
         );
         try {
             $json         = json_decode($this->jiraClient->get($uri)->getBody()->getContents(), true);
             $attachments  = $this->prepareSlackAttachments($json);
             $responseBody = [
                 'text'          => "Search Results for `{$body['command']} {$body['text']}`",
                 'response_type' => $body['response_type'] ?? 'ephemeral',
                 'attachments'   => $attachments,
             ];
             $this->slackClient->post($body['response_url'], ['body' => json_encode($responseBody)]);
         } catch (ClientException $e) {
             $error = $e->getMessage();
             $this->slackClient->post(
                 $body['response_url'],
                 [
                     'body' => json_encode(
                         [
                             'text' => "Running `{$body['command']} {$body['text']}` didn't work. Got "
                                 . $e->getCode() . " for an HTTP response",
                         ]
                     ),
                 ]
             );
         }
 
         return $next($request, $response, $error ?? null);
     }
 }
{% endhighlight %}
First, on line 30, we’re checking to make sure we’re looking at a request that looks something like `/jira show $ISSUE-KEY` Then, we’re saving the rest of the arguments in the request body for our request to JIRA later on.

The `UriTemplate` on line 34 from Guzzle makes it trivial to build a url dynamically using whatever data you need.

The request we’re making will use JIRA’s JQL to request whatever issues we’re asking for by sticking them in `jql=key in ({issueKeys*})`. The rest of the query are the fields we care about. If there are multiple issues passed in, the template will automatically split them up using a comma, which is just what we need.

After we have our uri built, we make a `GET` request using our JIRA client. That will return JSON data, which we hand into a function that formats our message in a format for slack to make it pretty. [You can see that bit of code here.](https://github.com/stringerbell/expressive-demo-jira-slack/blob/73975764f41ca38a8561e915f54145f80535f557/src/App/Service/Jira/JiraShowIssueCommand.php#L75-L104)

Guzzle will throw an exception if an invalid HTTP response or any other type of error happens. If that’s the case, we’re using our Slack client to send the error back to the user.

The factory for the above class looks like this `JiraShowIssueCommandFactory.php`:
{% highlight php linenos %}
<?php

namespace App\Service\Jira;

use App\Client\JiraClient;
use App\Client\SlackClient;
use Interop\Container\ContainerInterface;

class JiraShowIssueCommandFactory
 {
     public function __invoke(ContainerInterface $container)
     {
         $jiraClient  = $container->get(JiraClient::class);
         $slackClient = $container->get(SlackClient::class);
         $jiraUrl     = $container->get('config')['jira_config']['base_uri'] ?? '';
 
         return new JiraShowIssueCommand($jiraClient, $slackClient, $jiraUrl);
     }
 }
{% endhighlight %}
We are re-using our old Slack Client, and also using a JIRA client. It’s a bit different and has more config than our Slack Client. Here’s what it looks like.

{% highlight php linenos %}
<?php

namespace App\Client;

use GuzzleHttp\Client;
use Interop\Container\ContainerInterface;

class JiraClient
{
     public function __invoke(ContainerInterface $container)
     {
         $config  = $container->get('config')['jira_config'] ?? [];
         $auth    = $config['auth'] ?? [];
         $baseUri = $config['base_uri'] ?? '';
 
         return new Client(
             [
                 'base_uri' => $baseUri,
                 'auth'     => [($auth['user'] ?? ''), ($auth['password'] ?? '')],
                 'headers'  => [
                     'Content-Type' => 'application/json',
                 ],
             ]
         );
     }
 }
{% endhighlight %}
The main difference is that we know the `base_uri` for our JIRA instance, so we’ll construct it with that and we need to make requests using basic auth.

The config file that’s driving the factory above looks like this (`jira_config.local.php.dist`):
{% highlight php linenos %}
<?php

return [
    'jira_config' => [
        'auth' => ['user' => 'your JIRA username (not email)', 'password' => 'password'],
        'base_uri' => 'https://$yourJiraInstance.atlassian.net/',
    ],
];
{% endhighlight %}
It’s a `dist` file since it has our JIRA credentials in it. In production and locally, you should have a copy of this file with your real username and password to be able to make it work.

After all of these are created, be sure to add them to your dependencies config file. Expressive will throw an easy to understand error back at you if you forget though.

# **Final Steps**
We now have a working stack of middleware that receives, validates, and makes a query to JIRA.

Here’s a screenshot of an example result: 

![]({{ "http://i.imgur.com/j2kJsB0.png" }})

The last piece I added was to send a message back to the user on Slack when we’re done processing JIRA commands. [changeset 4c8ceb](https://github.com/stringerbell/expressive-demo-jira-slack/commit/4c8ceb644d804bf6ff246a6bb1133d05943923b6)

A handy thing you can do with Zend’s Service Manager is call build instead of get, with config options. Here’s what we’re adding to our pipeline.

{% highlight diff %}

class SlackJiraPipeline
 {
     public function __invoke(ContainerInterface $container)
     {
         $pipeline = new MiddlewarePipe();
         $pipeline->pipe($container->get(ValidateBody::class));
         $pipeline->pipe($container->get(ValidateSlackToken::class));
         $pipeline->pipe($container->get(ParseSlackJiraInput::class));
         $pipeline->pipe($container->get(JiraShowIssueCommand::class));
+        $pipeline->pipe(
+          $container->build(SendMessageToSlackUserViaResponseUrl::class, ['message' => 'Processing Complete'])
+        );
{% endhighlight %}
Here’s the corresponding middleware:

{% highlight php linenos %}
<?php

namespace App\Service\Slack;

use GuzzleHttp\Client;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;

class SendMessageToSlackUserViaResponseUrl
 {
     /**
      * @var Client
      */
     private $slackClient;
     /**
      * @var string
      */
     private $message;
 
     public function __construct(Client $slackClient, string $message)
     {
         $this->slackClient = $slackClient;
         $this->message     = $message;
     }
 
     public function __invoke(ServerRequestInterface $request, ResponseInterface $response, callable $next)
     {
         $body         = $request->getParsedBody();
         $responseBody = [
             'text'          => $this->message,
             'response_type' => $body['response_type'] ?? 'ephemeral',
         ];
         $this->slackClient->post($body['response_url'], ['body' => json_encode($responseBody)]);
 
         return $next($request, $response, $error ?? null);
     }
}
{% endhighlight %}
This takes in a Slack Client, and a message, and then uses that message to send to Slack via the `response_url` in the body.

Here’s the factory:

{% highlight php linenos %}
<?php

namespace App\Service\Slack;

use App\Client\SlackClient;
use Interop\Container\ContainerInterface;

class SendMessageToSlackUserViaResponseUrlFactory
{
     public function __invoke(ContainerInterface $container, $requestedName, array $options = [])
     {
         $defaults = [
             'message' => 'You sent a message, but forgot to replace the default! Go you! 
  You should probably use `build`',
         ];
         $options += $defaults;
         $slackClient = $container->get(SlackClient::class);
 
         return new SendMessageToSlackUserViaResponseUrl($slackClient, $options['message']);
     }
 }
{% endhighlight %}
Expressive will take in options that you pass to it at runtime. We set up a default message, and then pass it along to our middleware.

Here’s a screenshot of the result using the complete message at the end. We’re also passing in the `-p` option to post the result publicly.

![Slack Example]({{"http://i.imgur.com/0FPUluV.png"}})

That’s it! Hopefully you now have a good overview of how to connect Slack to JIRA, and potentially any other service using expressive.

One other practical considerations, is queuing requests, and responding to slack immediately instead of processing commands in real-time. You’ll probably get timeout errors from Slack if you’re not doing that, even though it’ll still probably work. Since this is already a really long post, I’ll have to cover how to do that in a different post.

Thanks for reading, and I hope you enjoyed it. Please feel free to ask me any questions you have via email or [twitter](https://twitter.com/dannnstockton). If you want me to walk through anything else that you think would be interested, I’d be especially interested to hear from you.