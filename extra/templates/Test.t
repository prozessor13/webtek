sub init   { }    #... place some code before calling the tests
sub finish { }    #... place some code after calling the tests

sub sample_test :Test(2) {  # define the number of test-fkt-calls in this test
   ok(1, 'sample test');
   is(2, 2, 'sample test2');
}
