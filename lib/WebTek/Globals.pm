package WebTek::Globals;

# max demmelbauer
# 07-03-06
#
# - exports all webtek global functions into the caller
# - inits the caller

require WebTek::Logger;
require WebTek::App;
require WebTek::Handler;
require WebTek::Config;
require WebTek::Timing;
require WebTek::Request;
require WebTek::Response;
require WebTek::Session;
require WebTek::Util;
require WebTek::Loader;
require WebTek::Html;
require WebTek::Model;
require WebTek::Attributes;
require WebTek::Exception;
require WebTek::DB;
require WebTek::Cache;
require WebTek::Data::Struct;
require WebTek::Data::Date;
require WebTek::Event;
require WebTek::Attributes;
require WebTek::Output;
require WebTek::Message;
require WebTek::Page;
require WebTek::Filter;
require WebTek::Parent;
require WebTek::Paginator;
require WebTek::Dispatcher;

sub import {
   export(qw(
      WebTek::App::app app
      WebTek::Logger::log_info log_info
      WebTek::Logger::log_error log_error
      WebTek::Logger::log_fatal log_fatal
      WebTek::Logger::log_debug log_debug
      WebTek::Logger::log_warning log_warning
      WebTek::Response::response response
      WebTek::Request::request request
      WebTek::Session::session session
      WebTek::Config::config config
      WebTek::Timing::timer_start timer_start
      WebTek::Timing::timer_end timer_end
      WebTek::Util::assert assert
      WebTek::Util::stash stash
      WebTek::Util::r r
      WebTek::Event::event event
      WebTek::Attributes::MODIFY_CODE_ATTRIBUTES MODIFY_CODE_ATTRIBUTES
      WebTek::DB::DB DB
      WebTek::Data::Struct::struct struct
      WebTek::Data::Date::date date
      WebTek::Cache::cache cache
      WebTek::Exception::throw2 throw
      WebTek::Util::comet_event comet_event
      WebTek::Model::DATA_TYPE_UNKNOWN DATA_TYPE_UNKNOWN
      WebTek::Model::DATA_TYPE_STRING DATA_TYPE_STRING
      WebTek::Model::DATA_TYPE_NUMBER DATA_TYPE_NUMBER
      WebTek::Model::DATA_TYPE_BOOLEAN DATA_TYPE_BOOLEAN
      WebTek::Model::DATA_TYPE_DATE DATA_TYPE_DATE
      WebTek::Model::DATA_TYPE_BLOB DATA_TYPE_BLOB
      WebTek::Model::DATA_TYPE_STRUCT DATA_TYPE_STRUCT
      WebTek::Model::DATA_TYPE_JSON DATA_TYPE_JSON
      WebTek::Model::DATA_TYPE_PERL DATA_TYPE_PERL
   ));
}

sub export {
   my $caller = caller(1);
   my %exports = @_;
   while (my ($sub, $method) = each %exports) {
      *{"$caller\::$method"} = \&{$sub} unless defined &{"$caller\::$method"};
   }
}

1;