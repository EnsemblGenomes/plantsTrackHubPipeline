package TransformDate;


use strict ;
use warnings;


my %months = (
        "jan" => "01",
        "feb" => "02",
        "mar" => "03",
        "apr" => "04",
        "may" => "05",
        "jun" => "06",
        "jul" => "07",
        "aug" => "08",
        "sep" => "09",
        "oct" => "10",
        "nov" => "11",
        "dec" => "12",
        "Jan" => "01",
        "Feb" => "02",
        "Mar" => "03",
        "Apr" => "04",
        "May" => "05",
        "Jun" => "06",
        "Jul" => "07",
        "Aug" => "08",
        "Sep" => "09",
        "Oct" => "10",
        "Nov" => "11",
        "Dec" => "12",
        "January" => "01",
        "February" => "02",
        "March" => "03",
        "April" => "04",
        "June" => "06",
        "July" => "07",
        "August" => "08",
        "September" => "09",
        "October" => "10",
        "November" => "11",
        "December" => "12",
        "january" => "01",
        "february" => "02",
        "march" => "03",
        "april" => "04",
        "june" => "06",
        "july" => "07",
        "august" => "08",
        "september" => "09",
        "october" => "10",
        "november" => "11",
        "december" => "12"
);



sub change_date {

 my $date = shift;

 if($date =~/(jan|January|Jan|january|feb|Feb|February|february|mar|March|Mar|march|apr|Apr|April|april|may|May|jun|Jun|June|june|jul|Jul|July|july|aug|Aug|August|august|sept|Sept|September|september|oct|Oct|October|october|nov|Nov|November|november|dec|Dec|December|december)?/){
   my $month = $1;
   my $correct_month = $months{$month};
   $date =~ s/$month/$correct_month/;
 }else{
   print STDERR "Did not get the expected month format in the date inside the ".__FILE__ ." module, I got $date while I was expecting this type: Jul, July, july or jul\n";
 }
 return $date;

}

1