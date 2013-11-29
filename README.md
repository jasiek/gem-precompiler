# GemPrecompiler

When deploying to a large number of identical servers, it makes sense to provide each installation with a precompiled versions of gems that have native components.
Those can be either bundled with the application, or distributed to a `rubygems.org`-like repository, from which they can be pulled in and installed. This particular
tool uses Amazon S3 to distribute the compiled gems for each architecture. All you need to do is add a `source` clause in your `Gemfile`.

## Prerequisites

* Ruby 1.9
* git
* wget
* a working compiler

## Installation

Clone this repository, and run `bundle install`. 

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
