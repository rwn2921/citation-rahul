#!/usr/lib/perl5

#test changes

#perl d:/Working/BookMetrix/bookmetrix.pl -d "10.1007/978-0-387-77650-7_5" -l "d:/Working/BookMetrix/LOGS" -r "STAT.txt" -c "cmd"
#perl d:/Working/BookMetrix/bookmetrix.pl -d "10.1007/978-1-4614-4475-6_7" -l "d:/Working/BookMetrix/LOGS" -r "STAT.txt" -c "cmd"
#10.1007/987-1-4614-4475-6_7
#perl d:/Working/BookMetrix/Release/BookMetrix/bookmetrix.pl -d "10.1007/978-0-387-44956-2_24" -l "d:/Working/BookMetrix/LOGS/TTTT" -r "STAT.txt" -c "cmd"        #shorst
#perl d:/Working/BookMetrix/bookmetrix.pl -d "10.1007/978-0-387-44956-2_24" -l "d:/Working/BookMetrix/LOGS/TTTT" -r "STAT.txt" -w "html"       #shorst
#perl d:/Working/BookMetrix/bookmetrix.pl -d "bbm:978-1-4020-3714-6/1" -l "d:/Working/BookMetrix/TEMP" -r "STAT1.txt"
#perl d:/Working/BookMetrix/bookmetrix.pl -d "10.1007/3-540-34416-0_18" -l "d:/Working/BookMetrix/LOGS" -r "STAT.txt" -c "cmd"


#####################################################################################################################################################
BEGIN{
	system ("clear");
	use Cwd qw/ realpath /;

	$SCRITPATH = realpath($0);

	#$SCRITPATH=$0;
	#chomp($SCRITPATH);
	print "sript path is \[$SCRITPATH\]\n";  
	$SCRITPATH=~s/(.*)([\/\\])(.*?)\.(pl|exe)/$1/g;
	$SCRITPATHpwd=$SCRITPATH;
	$SCRITPATHLocalLib=$SCRITPATH."/lib";
	$SCRITPATHPM="$SCRITPATH"."/warnings.pm";
	$ModulesPath = "$SCRITPATH"."/Modules";
print "sript path is ModulesPath = $ModulesPath\n";
	if (-d $SCRITPATHLocalLib){
		unshift(@INC, "$SCRITPATHLocalLib");
		unshift(@INC, "$SCRITPATH");
		unshift(@INC, "$SCRITPATHPM");
		unshift(@INC, "$ModulesPath");
	}else{
		unshift(@INC, "$SCRITPATH");
		print "\n\n\n\n\t\t***************\n \"$SCRITPATHLocalLib\"\n  Missing! \n\t\t***************\n\n\n\n"
	}
;
  
print "\n\nFinal script path is $SCRITPATH\n";

}


my $Version="1.5";
use warnings;
use LWP::UserAgent;
use Getopt::Long ();
use Data::Dumper;
use XML::Model;
use UTF8::utfEntities;
use DBConnection;
use BookMetrix::openReturnFileData;

my $SCRITPATH=$0;
$SCRITPATH=~s/(.*)([\/\\])(.*?)\.(pl|exe)/$1/g;
my $command = $0;
my $file;
my $string;
my $author;
my $title;
my $page;
my $cline;
my $doi;
my $help;
my $version;
my $reportfile;
my $logpath;
my $webservice;




Getopt::Long::GetOptions(
   'f|filelocation=s' => \$file,
   'a|author=s' => \$author,
   't|title=s' => \$title,
   'p|page=s' => \$page,
   'd|doi=s' => \$doi,
   'c|cline=s' => \$cline,
   'w|webservice=s' => \$webservice,
   'r|reportfile=s' => \$reportfile,
   'l|loglocation=s' => \$logpath,
   'h|?|help' => \$help,
   'v|version' => \$version,
)

or usage("Invalid commmand line options.");

###Command Line Arguments Validations
&help if(defined $help);

if (defined $version){
  my $scriptname=$command;
  $scriptname=~s/^(.*)([\/\\])(.*?)\.([a-z]+)$/$3\.$4/gs;
  print "\nThis is $scriptname, version $Version";
  exit 0;
}

usage("\nThe file name or DOI must be specified.") if(!defined $file && !defined $doi);

if(defined $file){
  chomp($file);
  if(!-e $file){
    print "\nError: $file not exist\n";
    exit 1;
  }
}


$logpath=$SCRITPATH if (!defined $logpath);

my $logFileLocation=$logpath;
chomp($logFileLocation);
$logFileLocation=~s/([\/\\])$//gs;

if(!-d $logFileLocation){
  my $mkdir="mkdir \"$logFileLocation\"";
  system($mkdir);
}

my $overallStatFile="";

if(defined $reportfile){
  if($reportfile!~/^(.*)\.db$/){
    if($reportfile=~/([\\\/])/){
      $overallStatFile=$reportfile;
       my $overallStatFileLoc=$overallStatFile;
      $overallStatFileLoc=~s/^(.*)[\/\\](.+?)$/$1/gs;
      if(!-d $overallStatFileLoc){
	my $mkdir="mkdir \"$overallStatFileLoc\"";
	system($mkdir);
      }
    }else{
      $overallStatFile="$logFileLocation"."\/"."$reportfile";
    }
  }
}
#============================================================ Main =======================================================================================


#####Cited-By Count using http://citationsapi.nkb3.org/article/citations/count?doi=$doi API
my $citation = &CitationCount($doi);

print "\n====== citation =============\n";
print Dumper $citation;

my $fileContent="";
my $outData="";
my %bistructure=();
my $bistructureRef=\%bistructure;
my @bistructureID=();
my $bistructureIDRef=\@bistructureID;
$$bistructureRef{ChapterDOI}="$doi";
$$bistructureRef{LogLoc}="$logFileLocation";
$$bistructureRef{CitedBy}="$citation";

print "Connect Springer Link Data\n"  if(defined $cline);

###### Get SpringerLink XML using "http://content-api.springer.com/document/$doi" API 
###### Parse fetched XML and get Structrured Hash Ref and ID "bistructureRef, bistructureIDRef"

($bistructureRef, $bistructureIDRef)=&Get_SpringerLink_XML($doi);



print "Get Structure Refrences\n" if(defined $cline);

##Total Reference Count
$$bistructureRef{"RefCount"}= scalar @$bistructureIDRef;

$$bistructureRef{"SpringerLinkCount"}=0;
$$bistructureRef{"CrossRefMetaCount"}=0;
$$bistructureRef{"CrossRefWebCount"}=0;
$$bistructureRef{"ResearchGateCount"}=0;
$$bistructureRef{"SpringerLinkFuzzyCount"}=0;
$$bistructureRef{"BibUnstructuredCount"}=0;
$$bistructureRef{"BibStructuredCount"}=0;
$$bistructureRef{"SpellingMistakes"}="NULL";
$$bistructureRef{"WrongDOI"}="0";
$$bistructureRef{"ISBN"}="NULL";
$$bistructureRef{"WebLink"}="NULL";
$$bistructureRef{"DOIObtainedForSpringerPublished"}="0";
$$bistructureRef{"DOIObtainedForNonSpringer"}="0";
$$bistructureRef{"DOIObtainedFromStructuredRef"}="0";
$$bistructureRef{"DOIObtainedFromUnstructuredRef"}="0";


#print "\n bistructure \n";
#print Dumper $bistructureRef;


#print "\n bistructureIDRef \n";
#print Dumper $bistructureIDRef;
#exit;

######BibUnstructuredCount Count
foreach my $bibID (@$bistructureIDRef){
  $$bistructureRef{SpringerLinkCount}++ if(exists $$bistructureRef{"$bibID"}{DOISource});
  if(exists $$bistructureRef{"$bibID"}{Bibtype}){
    $$bistructureRef{BibUnstructuredCount}++ if($$bistructureRef{"$bibID"}{Bibtype} eq "BibUnstructured");
  }
}

######BibStructuredCount Count
$$bistructureRef{"BibStructuredCount"} = $$bistructureRef{"RefCount"} - $$bistructureRef{"BibUnstructuredCount"};
#========================================================================================================================================================

######Parse Unstructured Refrences using Reflexica
my $refHtm=$$bistructureRef{ChapterDOI} . "_Ref\.htm";

print "\n refHtm = $refHtm \n";
$refHtm=~s/\//\%2F/gs;
$refHtm=~s/bbm\:/bbm\-/gs;
my $RefInputFile=$$bistructureRef{LogLoc} . "\/" . $refHtm;
if (-e $RefInputFile){
  #$bistructureRef=BibUnstructuredParse($bistructureRef, $bistructureIDRef, $RefInputFile);
  #print "\n bistructureRef =========\n ";
#print Dumper $bistructureRef;exit;
  
}


######Get DOI from Crossref [CrossRef META, CrossRef Web, ResearchGate Scraping]
$bistructureRef=&Get_Crossref_DOI($bistructureRef, $bistructureIDRef);

######Get DOI from FUZZY Search [SpringerLink, CrossRef, Scopus]
#$bistructureRef=&Get_Fuzzy_DOI($bistructureRef, $bistructureIDRef);

######DOI Validation from CrossRef and SpringerLink
$bistructureRef=&DOI_Validation($bistructureRef, $bistructureIDRef);

######Identify and counts for Springer/Non Springer Bibs
$bistructureRef=&Identify_BibPublisherName($bistructureRef);

######Generate Report and Statistics with retrieved DOI for Chapter/Article References
&Generate_Report_and_Statistics;

####################################################### MAIN END ###################################################################################
#####################################################################################################################################################

sub usage{
  my $message = $_[0];
  if (defined $message && length $message) {
    $message .= "\n"
      unless $message =~ /\n$/;
  }
  print STDERR (
		$message,
		"usage: $command -d \"doi\"  -l logpath [-r reportfile] [-c|cline] [-w|webservice] [-v|version] [-h|help]\n\n\tOR\n\n" .
		"usage: $command -doi \"doi\" -loglocation \"logpath\" -reportfile \"REPORT.txt\" -c \"cmd\"\n" .
		"       ...\n"
	       );
  die("\n")
}
#==========================================================================================================================================================
sub help{
  print "################################################################################\n";
  print "\nScope: Get DOI From Cross Ref\n\n";
  print "usage: $command -d \"doi\"  -l logpath [-r reportfile] [-c|cline] [-w|webservice] [-v|version] [-h|help]\n\n\tOR\n\n";
  print "$command -d \"10.1007/978-0-387-77650-7_5\" -l \"d:/Working/BookMetrix/LOGS\" -r \"STAT.txt\" -c \"cmd\"\n\n";
  print "################################################################################\n";
  exit 3;
}
#==========================================================================================================================================================
sub Get_SpringerLink_XML{
  my $doi=shift;
  my $WebContent="";
  my $urlArgument="";
  my $content_type='application/x-www-form-urlencoded';
  $doi=~s/\//\%2F/gs;
  my $url="http://content-api.springer.com/document/$doi";      #Springer Content API
  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new(GET => $url);
  $req->content_type($content_type);
  $req->content($urlArgument);
  my $res = $ua->request($req);
  my $webData=$res->content;
  my $crossRefData="";

  #take Any Hash Ref, Hash ref ID, and XML content, retuen XML hash ref and id ref
  if ($res->is_success){
    my $SpringerXML="${logFileLocation}\/${doi}\.xml";
	
#print "\nbefore SpringerXML". "$SpringerXML \n";

    $SpringerXML=~s/bbm\:/bbm\-/gs;
	
#print "\nafter SpringerXML". "$SpringerXML \n";

    #Write  A++ XML at log location
    open(OUTFILE, ">", "$SpringerXML") || die("$SpringerXML File cannot be writing\n");
    print OUTFILE $webData;
    close(OUTFILE);

    #Parse fetched XML Reference Data and get Structrured Hash Ref and Ref ID
    ($bistructureRef, $bistructureIDRef)=&Parser($webData, $bistructureRef, $bistructureIDRef, "nested");

  }else{
    print $res->status_line, "\n";
    $$bistructureRef{"Error"}="$res->status_line";
    $crossRefData=$webData;
  }
  return ($bistructureRef, $bistructureIDRef);
}
#==========================================================================================================================================================
sub printRefStructure{
  my ($bistructureRef, $bistructureIDRef, $counter, $bibID, $CitationData)=@_;
  print $$bistructureRef{"$bibID"}{"bibID"}, " => ", $$bistructureRef{"$bibID"}{"Bibtype"}, "\n" if(defined $cline);
  print $$bistructureRef{"$bibID"}{"BibUnstructured"} if(defined $cline);
  if(exists $$bistructureRef{"$bibID"}{"DOI"}){
    print " \[DOI ", $$bistructureRef{"$bibID"}{"DOI"}, "\]\n" if(defined $cline);
  }
  print "\n" if(defined $cline);
  print "\n$$bistructureIDRef[$counter] => \n" if(defined $cline);
  print $CitationData if(defined $cline);
}
#=======================================================================================================
sub Get_Crossref_DOI{
  my ($bistructureRef, $bistructureIDRef)=@_;
  print "CrossRef META DOI Query in process \[$$bistructureRef{ChapterDOI}\]\n\n" if(defined $cline);

  foreach my $bibID (@$bistructureIDRef){

    my ($Author, $Editor, $BookJournalTitle, $articleChapterTitle, $page, $volume, $year, $search_type)=&BibInfo($bistructureRef, $bibID);

    #if($$bistructureRef{"$bibID"}{"bibID"} ne ""){ #testBlock #testCase

	#___________________Crossref Meta______________________
      if(!exists $$bistructureRef{"$bibID"}{"DOI"}){  
#print "\n $bibID , $Author, $Editor, $BookJournalTitle, $articleChapterTitle, $page, $volume, $year, $search_type \n";	  
	my $DOI="";
	print "$bibID\n" if(defined $cline);
	($bistructureRef, $DOI)=&Get_CrossrefMeta_DOI($bistructureRef, $bibID, "ChapterBook");    ##  Call function for ChapterBook
	if (!exists $$bistructureRef{"$bibID"}{"DOI"}){
	  ($bistructureRef, $DOI)=&Get_CrossrefMeta_DOI($bistructureRef, $bibID, "Book");         ## Call function for Other Type
	  if ($DOI ne ""){
	    print "\t\tDOI found from CrossRef META query2\n" if(defined $cline);
		insert_citation_data($bistructureRef, $DOI, $bibID);exit;
	  }
	}else{
	  print "\t\tDOI found from CrossRef META query\n" if(defined $cline);

	  my $id="";
	  $id = check_DOI_exists($DOI);
		
		#print "\n id = $id \n";
	  if (!$id){
		insert_citation_data($bistructureRef, $DOI, $bibID);exit;
	  }
	}

	#___________________Crossref WEB______________________

	if (!exists $$bistructureRef{"$bibID"}{"DOI"}){
	  ($bistructureRef, $DOI)=Get_CrossrefWeb_DOI($bistructureRef, $bibID);
	  if ($DOI ne ""){
	    print "\t\tDOI found from CrossRef Web Scraping\n" if(defined $cline);
		insert_citation_data($bistructureRef, $DOI, $bibID);exit;
	  }
	}
	#___________________Research Gate_____________________

	if (!exists $$bistructureRef{"$bibID"}{"DOI"}){
	  if($articleChapterTitle ne ""){
	    ($bistructureRef, $DOI)=Get_ResearchGate_DOI($bistructureRef, $bibID, "ChapterBook");
	    if ($DOI ne ""){
	      print "\t\tDOI found from ResearchGate Scraping\n" if(defined $cline);
		  insert_citation_data($bistructureRef, $DOI, $bibID);exit;
	    }
	  }
	}
	if (!exists $$bistructureRef{"$bibID"}{"DOI"}){
	  if (exists $$bistructureRef{"$bibID"}{"BookTitle"}){
	    ($bistructureRef, $DOI)=Get_ResearchGate_DOI($bistructureRef, $bibID, "Book");
	    if ($DOI ne ""){
	      print "\t\tDOI found from ResearchGate Scraping\n" if(defined $cline);
		  insert_citation_data($bistructureRef, $DOI, $bibID);exit;
	    }
	  }
	}
      }#if key exist Block end
    #}#test if Block
  }#Foreach End 
  return $bistructureRef;
}
#==========================================================================================================================================================
sub Get_CrossrefMeta_DOI{
  my ($bistructureRef, $bibID, $searchCase)=@_;

  my ($Author, $Editor, $BookJournalTitle, $articleChapterTitle, $page, $volume, $year, $search_type)=&BibInfo($bistructureRef, $bibID);
  my $host="www.crossref.org";
  my $content_type='application/x-www-form-urlencoded';
  my $url="";
  my $urlArgument="";

  my $titleForSearch="";

  if($searchCase eq "ChapterBook"){
    $url="http://www.crossref.org/guestquery/#bibsearch";
    $urlArgument="queryType=bibsearch&search_type=$search_type&auth=$Author&issn=&title=$BookJournalTitle&atitle=$articleChapterTitle&volume=&issue=&page=$page&year=&isbn=&compnum=&stitle=&multi_hit=true&view_records=Search";
    if ($articleChapterTitle ne ""){
      $titleForSearch=$articleChapterTitle;
    }else{
      $titleForSearch=$BookJournalTitle;
    }
  }else{
    $url="http://www.crossref.org/guestquery";
    if ($Editor ne ""){
      if(exists $$bistructureRef{"$bibID"}{"Editor_FamilyParticle_1"}){
	$Editor=$Editor . " ". $$bistructureRef{"$bibID"}{"Editor_FamilyParticle_1"}; 
      }
      if ($search_type eq "journal"){
	$urlArgument="queryType=author-title&auth2=$Editor&atitle2=$articleChapterTitle&multi_hit=true&article_title_search=Search";
	$titleForSearch=$articleChapterTitle;

      }else{
	$urlArgument="queryType=author-title&auth2=$Editor&atitle2=$BookJournalTitle&multi_hit=true&article_title_search=Search";
	$titleForSearch=$BookJournalTitle;
      }
    }else{
      if(exists $$bistructureRef{"$bibID"}{"Author_FamilyParticle_1"}){
	$Author=$Author . " ". $$bistructureRef{"$bibID"}{"Author_FamilyParticle_1"};
      }
      if ($search_type eq "journal"){
	$urlArgument="queryType=author-title&auth2=$Author&atitle2=$articleChapterTitle&multi_hit=true&article_title_search=Search";
	$titleForSearch=$articleChapterTitle;
      }else{
	$urlArgument="queryType=author-title&auth2=$Author&atitle2=$BookJournalTitle&multi_hit=true&article_title_search=Search";
	$titleForSearch=$BookJournalTitle;
      }
    }
  }

# print "\n URL is ===\n";
# print $url;

# print "\nurl argument ==\n";
# print $urlArgument;
# print "\nurl argument ==\n";

  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new(POST => $url);
  $req->content_type($content_type);
  $req->content($urlArgument);
  
# print Dumper $req;
  
  my $res = $ua->request($req);
  my $webData=$res->content;
  
# print "\n res == \n";
# print Dumper $res; 

# print "\n webdata == \n";
# print Dumper $webData;exit;
  my $DOI="";
  if ($res->is_success){
    if($webData=~s/<tr[^<>]*?><td[^<>]*?>\Q$titleForSearch\E<td[^<>]*?>((?:(?!<[\/]?table>)(?!<a href\=)(?!<[\/]?tr>)(?!<tr [^<>]+?>)(?!<table [^<>]+?>).)*)$year<tr[^<>]*?>\s*<td[^<>]*?>\s*<a href=(http\:\/\/dx\.doi\.org\/)([^<>]+?)>([^<>]+?)<\/a>//is){
      $DOI="$3";
      $$bistructureRef{"$bibID"}{"DOI"}=$DOI;
      $$bistructureRef{"$bibID"}{"DOISource"}="CrossRef-Meta";
      $$bistructureRef{"CrossRefMetaCount"}=$$bistructureRef{"CrossRefMetaCount"} + 1;
      print "\tDOI: $DOI\n" if(defined $cline);
    }elsif($webData=~s/<tr[^<>]*?><td[^<>]*?>\Q$titleForSearch\E<td[^<>]*?>((?:(?!<[\/]?table>)(?!<a href\=)(?!<[\/]?tr>)(?!<tr [^<>]+?>)(?!<table [^<>]+?>).)*)<tr[^<>]*?>\s*<td[^<>]*?>\s*<a href=(http\:\/\/dx\.doi\.org\/)([^<>]+?)>([^<>]+?)<\/a>//is){
      $DOI="$3";
      $$bistructureRef{"$bibID"}{"DOI"}=$DOI;
      $$bistructureRef{"$bibID"}{"DOISource"}="CrossRef-Meta";
      $$bistructureRef{"CrossRefMetaCount"}=$$bistructureRef{"CrossRefMetaCount"} + 1;
      print "\tDOI: $DOI\n" if(defined $cline);
    }elsif($webData=~s/$year<tr[^<>]*?>\s*<td[^<>]*?>\s*<a href=(http\:\/\/dx\.doi\.org\/)([^<>]+?)>([^<>]+?)<\/a>//is){
      $DOI="$2";
      $$bistructureRef{"$bibID"}{"DOI"}=$DOI;
      $$bistructureRef{"$bibID"}{"DOISource"}="CrossRef-Meta";
      $$bistructureRef{"CrossRefMetaCount"}=$$bistructureRef{"CrossRefMetaCount"} + 1;
      print "\tDOI: $DOI\n" if(defined $cline);
    }elsif($webData=~s/<a href=(http\:\/\/dx\.doi\.org\/)([^<>]+?)>([^<>]+?)<\/a>//s){
      $DOI="$2";
      $$bistructureRef{"$bibID"}{"DOI"}=$DOI;
      $$bistructureRef{"$bibID"}{"DOISource"}="CrossRef-Meta";
      $$bistructureRef{"CrossRefMetaCount"}=$$bistructureRef{"CrossRefMetaCount"} + 1;
      print "\tDOI: $DOI\n" if(defined $cline);
    }
  }

  return ($bistructureRef, $DOI);
}
#==========================================================================================================================================================
sub Get_CrossrefWeb_DOI{
  my ($bistructureRef, $bibID)=@_;
  my ($Author, $Editor, $BookJournalTitle, $articleChapterTitle, $page, $volume, $year, $search_type)=&BibInfo($bistructureRef, $bibID);
  my $content_type='application/x-www-form-urlencoded';
  my $url="http://search.crossref.org/";
  my $host="search.crossref.org";
  my $urlArgument="";

  if ($BookJournalTitle ne ""){
    if($Author ne ""){
      if($year ne ""){
	$urlArgument="q=$Author $year $BookJournalTitle";
      }else{
	$urlArgument="q=$Author $BookJournalTitle";
      }
    }else{
      $urlArgument="q=$BookJournalTitle";
    }
  }

# print "\nurl args =====\n";
# print "\n  $urlArgument \n";

  my $crossRefData="";
  my $DOI="";

  if($urlArgument ne ""){
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(GET => $url);
    $req->content_type($content_type);
    $req->content($urlArgument);
    my $res = $ua->request($req);
    my $webData=$res->content;

# print "\n===req===\n";  
# print Dumper $req;  
  
# print "\n res == \n";
# print Dumper $res; 

# print Dumper $webData;exit;	

    if ($res->is_success){
      while($webData=~s/<span class=\"([^<>\"]+?)\">([^<>]+?)<\/span>([^<>]+?)<span class=\"\1\">/<span class=\"$1\">$2$3/gs){}
      while($webData=~s/([\w\.\,\;\:\?]+)\+([\w]+)/$1 $2/gs){}
      if ($articleChapterTitle eq ""){
	$articleChapterTitle=$BookJournalTitle;
      }
      if($webData=~s/<a class=\'cite-link\' href=\"javascript\:showCiteBox\(\'(http\:\/\/dx\.doi\.org\/)([^<>\']+?)\', \'\Q$articleChapterTitle\E([\.\,\?]*)\'\)\;\">//is){
	$DOI="$2";
	$$bistructureRef{"$bibID"}{"DOI"}=$DOI;
	$$bistructureRef{"$bibID"}{"DOISource"}="CrossRef-Web";
	$$bistructureRef{"CrossRefWebCount"}=$$bistructureRef{"CrossRefWebCount"} + 1;
      }
    }
  }
  return ($bistructureRef, $DOI);
}
#==========================================================================================================================================================
sub BibInfo{
  my ($bistructureRef, $bibID)=@_;
  my ($Author, $Editor, $BookJournalTitle, $articleChapterTitle, $page, $volume, $year, $search_type)=("", "", "", "", "", "", "", "");


  if(exists $$bistructureRef{"$bibID"}{"JournalTitle"}){
    $search_type="journal";
    $BookJournalTitle=$$bistructureRef{"$bibID"}{"JournalTitle"};
  }elsif(exists $$bistructureRef{"$bibID"}{"BookTitle"}){
    $search_type="books";
    $BookJournalTitle=$$bistructureRef{"$bibID"}{"BookTitle"};
  }
  if(exists $$bistructureRef{"$bibID"}{"ArticleTitle"}){
    $search_type="journal";
    $articleChapterTitle=$$bistructureRef{"$bibID"}{"ArticleTitle"};
  }elsif(exists $$bistructureRef{"$bibID"}{"ChapterTitle"}){
    $search_type="books";
    $articleChapterTitle=$$bistructureRef{"$bibID"}{"ChapterTitle"};
  }
  if(exists $$bistructureRef{"$bibID"}{"Author_FamilyName_1"}){
    $Author=$$bistructureRef{"$bibID"}{"Author_FamilyName_1"};
  }elsif(exists $$bistructureRef{"$bibID"}{"Editor_FamilyName_1"}){
    $Author=$$bistructureRef{"$bibID"}{"Editor_FamilyName_1"};
  }
  if(exists $$bistructureRef{"$bibID"}{"Editor_FamilyName_1"}){
    $Editor=$$bistructureRef{"$bibID"}{"Editor_FamilyName_1"};
  }

  $year = $$bistructureRef{"$bibID"}{"Year"} if(exists $$bistructureRef{"$bibID"}{"Year"});
  $volume = $$bistructureRef{"$bibID"}{"VolumeID"} if(exists $$bistructureRef{"$bibID"}{"VolumeID"});
  $page = $$bistructureRef{"$bibID"}{"FirstPage"} if(exists $$bistructureRef{"$bibID"}{"FirstPage"});


  return ($Author, $Editor, $BookJournalTitle, $articleChapterTitle, $page, $volume, $year, $search_type);
}
#==========================================================================================================================================================
sub Generate_Report_and_Statistics{

  ###Total DOI Found
  my $totalDOIFound= $$bistructureRef{SpringerLinkCount} + $$bistructureRef{CrossRefMetaCount} + $$bistructureRef{CrossRefWebCount} + $$bistructureRef{ResearchGateCount} + $$bistructureRef{SpringerLinkFuzzyCount};

  ###Total Obtain DOI (CrossRefMetaCount, CrossRefWebCount, ResearchGateCount, SpringerLinkFuzzyCount)
  my $totalObtainDOI=  $$bistructureRef{CrossRefMetaCount} + $$bistructureRef{CrossRefWebCount} + $$bistructureRef{ResearchGateCount} + $$bistructureRef{SpringerLinkFuzzyCount};

  ###Non Springer references count
 $$bistructureRef{"DOIObtainedForNonSpringer"} = $totalObtainDOI - $$bistructureRef{DOIObtainedForSpringerPublished};
 $$bistructureRef{MissingDOI} = $$bistructureRef{RefCount} -  $totalDOIFound;

  ###DOI Obtained From UnstructuredRef
  foreach my $bibID (@$bistructureIDRef){
    if(exists $$bistructureRef{"$bibID"}{Bibtype}){
      if($$bistructureRef{"$bibID"}{Bibtype} eq "BibUnstructured"){
	if(exists $$bistructureRef{"$bibID"}{DOISource}){
	  if($$bistructureRef{"$bibID"}{"DOISource"} ne "SpringerLink"){
	    $$bistructureRef{DOIObtainedFromUnstructuredRef}++;
	  }
	}
      }
    }
  }


  ###DOI Obtained From StructuredRef
  $$bistructureRef{"DOIObtainedFromStructuredRef"} = $totalObtainDOI - $$bistructureRef{DOIObtainedFromUnstructuredRef};

  my $outFileString = "<H1>Chapter DOI: $doi<br\/>Cited-By Count: $citation<\/H1>";
  $outFileString = $outFileString. "<table border=\"1\" width=\"30\%\"><tr><td>Total References<\/td><td>$$bistructureRef{RefCount}<\/td><\/tr><tr><td>Springer references<\/td><td>$$bistructureRef{SpringerRef}<\/td><\/tr><tr><td>Non Springer references<\/td><td>$$bistructureRef{NonSpringerRef}<\/td><\/tr><tr><td>BibStructured Count<\/td><td width\=\"10\%\">$$bistructureRef{BibStructuredCount}<\/td><\/tr><tr><td>BibUnstructured Count<\/td><td width\=\"10\%\">$$bistructureRef{BibUnstructuredCount}<\/td><\/tr><tr><td>DOI already available in SpringerLink<\/td><td>$$bistructureRef{SpringerLinkCount}<\/td><\/tr><tr><td>Additional DOI extracted from CrossRef-Meta<\/td><td>$$bistructureRef{CrossRefMetaCount}<\/td><\/tr><tr><td>Additional DOI extracted from CrossRef-Web<\/td><td>$$bistructureRef{CrossRefWebCount}<\/td><\/tr><tr><td>Additional DOI extracted from ResearchGate-Web<\/td><td>$$bistructureRef{ResearchGateCount}<\/td><\/tr><tr><td>Additional DOI extracted from SpringerLink-FUZZY-Search<\/td><td>$$bistructureRef{SpringerLinkFuzzyCount}<\/td><\/tr><tr><td>Spelling Mistakes<\/td><td>$$bistructureRef{SpellingMistakes}<\/td><\/tr><tr><td>Wrong DOI<\/td><td>$$bistructureRef{WrongDOI}<\/td><\/tr><tr><td>ISBN<\/td><td>$$bistructureRef{ISBN}<\/td><\/tr><tr><td>Web Link<\/td><td>$$bistructureRef{WebLink}<\/td><\/tr><tr><td>DOI Obtained For Springer Published<\/td><td>$$bistructureRef{DOIObtainedForSpringerPublished}<\/td><\/tr><tr><td>DOI Obtained For Non Springer<\/td><td>$$bistructureRef{DOIObtainedForNonSpringer}<\/td><\/tr><tr><td>DOI Obtained From Structured Ref<\/td><td>$$bistructureRef{DOIObtainedFromStructuredRef}<\/td><\/tr><tr><td>DOI Obtained From Unstructured Ref<\/td><td>$$bistructureRef{DOIObtainedFromUnstructuredRef}<\/td><\/tr><\/table><\/br><\/br>";

  #DOI obtained (Crossref, Reflexica)
 $$bistructureRef{DOIObtainedDirectSources} = $$bistructureRef{CrossRefMetaCount} + $$bistructureRef{CrossRefWebCount} + $$bistructureRef{ResearchGateCount};

  #my $overAllStatistic="${doi}\|${citation}\|$$bistructureRef{RefCount}\|$$bistructureRef{BibUnstructuredCount}\|$$bistructureRef{SpringerLinkCount}\|$$bistructureRef{CrossRefMetaCount}\|$$bistructureRef{CrossRefWebCount}\|$$bistructureRef{ResearchGateCount}|$$bistructureRef{SpringerLinkFuzzyCount}\|$$bistructureRef{MissingDOI}";
  #Over All Statistics based on CSV Formatter
  my $overAllStatistic=&readCSVFormatterIni($bistructureRef);

  $outFileString = $outFileString. "<table border=\"1\">\n<tr><th>Bib. ID</th><th>Ref. Type</th><th>References</th><th>DOI</th><th>Suspected DOI</th><th>DOI Source</th><th>Validated Elements</th><th>Validation Source</th></tr>";
  foreach my $bibID (@$bistructureIDRef){
    if(exists $$bistructureRef{"$bibID"}{"DOI"} or exists $$bistructureRef{"$bibID"}{"SuspectedDOI"}){

      if(exists $$bistructureRef{"$bibID"}{"SuspectedDOI"}){
	$outFileString=$outFileString . "<tr><td>";
	$outFileString=$outFileString . $$bistructureRef{"$bibID"}{"bibID"} . "<\/td><td>" . $$bistructureRef{"$bibID"}{"Bibtype"} . "<\/td><td>";
	$outFileString=$outFileString . $$bistructureRef{"$bibID"}{"BibUnstructured"} .  "</td><td>&nbsp;</td><td>" . "<a href=http://dx.doi.org/". $$bistructureRef{"$bibID"}{"SuspectedDOI"}.  ">" . $$bistructureRef{"$bibID"}{"SuspectedDOI"} . "<\/a></td><td><b>" . $$bistructureRef{"$bibID"}{"DOISource"} . "<\/b><\/td>\n";
      }else{
	$outFileString=$outFileString . "<tr><td>";
	$outFileString=$outFileString . $$bistructureRef{"$bibID"}{"bibID"} . "<\/td><td>" . $$bistructureRef{"$bibID"}{"Bibtype"} . "<\/td><td>";
	$outFileString=$outFileString . $$bistructureRef{"$bibID"}{"BibUnstructured"} .  "</td><td>" . "<a href=http://dx.doi.org/". $$bistructureRef{"$bibID"}{"DOI"}.  ">" . $$bistructureRef{"$bibID"}{"DOI"} . "<\/a></td><td>&nbsp;</td><td><b>" . $$bistructureRef{"$bibID"}{"DOISource"} . "<\/b><\/td>\n";
      }

      if(exists $$bistructureRef{"$bibID"}{"ValidatedElements"}){
	$outFileString=$outFileString . "<td>$$bistructureRef{$bibID}{ValidatedElements}<\/td><td>$$bistructureRef{$bibID}{ValidationSource}<\/td>";
      }elsif($$bistructureRef{"$bibID"}{"DOISource"} eq "SpringerLink"){
	$outFileString=$outFileString . "<td align\=center>---<\/td><td align\=center>---<\/td>";
      }else{
	$outFileString=$outFileString . "<td align\=center><font color=\"red\"><b>NOT MATCHED!<\/b><\/font><\/td><td>CrossRef, SpringerLink<\/td>";
      }
      $outFileString=$outFileString . "<\/tr>";
    }else{
      $outFileString=$outFileString . "<tr><td>";
      if(exists $$bistructureRef{"$bibID"}{"Bibtype"}){
	$outFileString=$outFileString . $$bistructureRef{"$bibID"}{"bibID"} . "<\/td><td>" . $$bistructureRef{"$bibID"}{"Bibtype"} . "<\/td><td>";
      }else{
	$outFileString=$outFileString . $$bistructureRef{"$bibID"}{"bibID"} . "<\/td><td>\&nbsp\;<\/td><td>";
      }
      $outFileString=$outFileString . $$bistructureRef{"$bibID"}{"BibUnstructured"} . "<\/td><td>\&nbsp\;<\/td><td>\&nbsp\;<\/td><td>\&nbsp\;<\/td><td>\&nbsp\;<\/td><td>\&nbsp\;<\/td>";
      $outFileString=$outFileString . "<\/tr>";
    }
  }

  $outFileString=$outFileString . "</table>";
  $outFileString=unicodeEntitiesConv($outFileString, "NormalText", "DecEntity", "utf8");#unicode to texEntities
  $doi=~s/\//\%2F/gs;


  my $xmlLogString="";
  my $HtmlReport="";
  if(defined $webservice){
    if($webservice eq "xml"){
      $xmlLogString=&XmlLog();
      print $xmlLogString;
    }elsif($webservice eq "json"){
      use XML::XML2JSON;
      $xmlLogString=&XmlLog();
      my $JSON="";
      eval{
	my $XML2JSON = XML::XML2JSON->new();
	$JSON = $XML2JSON->convert($xmlLogString);
	$JSON=~s/\:\"\\n([\s]+)/\:\"/gs;
	$JSON=~s/\\n([\s]+)/ /gs;
	$JSON=~s/(\"\:)\{\"\$t\"\:\"(.*?)\"\}/$1\"$2\"/gs;
      }; warn $@ if $@;
      print $JSON;
    }elsif($webservice eq "html"){
      $HtmlReport="${logFileLocation}\/${doi}\.html";
      $HtmlReport=~s/bbm\:/bbm\-/gs;
      print "<html>$outFileString<\/html>";
    }
  }else{
    $HtmlReport="${logFileLocation}\/${doi}\.html";
    $HtmlReport=~s/bbm\:/bbm\-/gs;
    open(OUTFILE, ">", "$HtmlReport") || die("$HtmlReport File cannot be writing\n");
    print OUTFILE $outFileString;
    close(OUTFILE);
  }

  if($reportfile=~/\.db$/){
    #&RecordInsert($bookDoi, \@chapDoiList, $reportfile);  #Inprocess
  }else{
    if($overallStatFile ne ""){
      if(-e $overallStatFile){
	open(APPENDFILE, ">>", "$overallStatFile") || die("$overallStatFile File cannot be writing\n");
	print APPENDFILE "$overAllStatistic\n";
	close APPENDFILE;
      }else{
	my $columnHeader=&readCSVHeader();
	open(WRITEFILE, ">", "$overallStatFile") || die("$overallStatFile File cannot be writing\n");
	print WRITEFILE "$columnHeader\n";
	print WRITEFILE "$overAllStatistic\n";
	close WRITEFILE;
      }
    }
  }

  print "Report Generated [$HtmlReport]\n" if(defined $cline);
}

#==========================================================================================================================================
sub CitationCount{
  my $doi=shift;
  my $WebContent="";
  my $content_type='application/x-www-form-urlencoded';
  my $urlArgument="";
  my $url="http://citationsapi.nkb3.org/article/citations/count?doi=$doi";
  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new(GET => $url);
  $req->content_type($content_type);
  $req->content($urlArgument);
  my $res = $ua->request($req);
  my $webData=$res->content;
 #print Dumper $webData;
  my $citation="";
  $citation=$1 if($webData=~/<citation-count>([^<>]+?)<\/citation-count>/);
  return $citation;
}

#==========================================================================================================================================
sub BibUnstructuredParse{
  my ($bistructureRef, $bistructureIDRef, $RefInputFile)=@_;

  print "BibUnstructured References process from Reflexica\n" if(defined $cline);
print "\n at BibUnstructuredParse SCRITPATH = $SCRITPATH\n";
  my $runTagtoColorScrpit= "\"${SCRITPATH}\/Reflexica\/RefManager.pl\" -f \"$RefInputFile\" -o color -x A++ -a Bookmetrix -c springerbookmetrix";

print "\n runTagtoColorScrpit = $runTagtoColorScrpit \n";

  system($runTagtoColorScrpit);
  undef $/;
  open(INFILE, "<:raw", "$RefInputFile") || die("$RefInputFile File cannot be opened\n");
  $refFileContent=<INFILE>;
  close(INFILE);
  
 #print "\n === $refFileContent ===  \n";

  $refFileContent=~s/\&lt\;bib id=\&quot\;(.*?)\&quot\;\&gt\;/<bib id=\"$1\">/gs;
  $refFileContent=~s/\&lt\;\/bib\&gt\;/<\/bib>/gs;
  
 #print "\n === $refFileContent ===  \n";exit;

  while($refFileContent=~s/<bib id=\"([^<>]+?)\">((?:(?!<[\/]?bib>)(?!<bib [^<>]+?>).)*)<\/bib>/\&lt\;bib id=\&quot\;$1\&quot\;\&gt\;$2\&lt\;\/bib\&gt\;/s){
    my $bibID=$1;
    my $Refcolor=$2;
    $$bistructureRef{"$bibID"}{"BibUnstructured"}=$Refcolor;
  }

  my $RefXMLFile=$RefInputFile;
  $RefXMLFile=~s/\_Ref\.htm/\_Ref\.xml/gs;
  my $refXMLContent="";
  open(INFILE, "<:raw", "$RefXMLFile") || die("$RefXMLFile File cannot be opened\n");
  $refXMLContent=<INFILE>;
  close(INFILE);

  $refXMLContent=unicodeEntitiesConv($refXMLContent, "HexaEntity", "NormalText", "utf8");#unicode to texEntities

  ($bistructureRef, $bistructureIDRef)=&Parser($refXMLContent, $bistructureRef, $bistructureIDRef, "oneline");

  
  my $RefInputFileTEMP=$RefInputFile;
  $RefInputFileTEMP=~s/\_Ref\.htm/\_Ref-org\.htm/s;

  unlink $RefXMLFile;
  unlink $RefInputFile;
  unlink $RefInputFileTEMP;

  return $bistructureRef;
}

#========================================================================================================================================================
sub Get_Fuzzy_DOI{
  my ($bistructureRef, $bistructureIDRef)=@_;

  print "\n\nFUZZY Search in process\n" if(defined $cline);

  foreach my $bibID (@$bistructureIDRef){
    if(!exists $$bistructureRef{"$bibID"}{"DOI"}){
      my ($DOI, $FuzzyTitle, $Author, $FuzzyDOI, $DOISource)=("", "", "", "", "");
      if(exists $$bistructureRef{"$bibID"}{"ArticleTitle"}){
	$FuzzyTitle=$$bistructureRef{"$bibID"}{"ArticleTitle"};
      }elsif(exists $$bistructureRef{"$bibID"}{"ChapterTitle"}){
	$FuzzyTitle=$$bistructureRef{"$bibID"}{"ChapterTitle"};
      }
      if(exists $$bistructureRef{"$bibID"}{"Author_FamilyName_1"}){
	$Author=$$bistructureRef{"$bibID"}{"Author_FamilyName_1"};
	$Author= $Author . " " . $$bistructureRef{"$bibID"}{"Author_Initials_1"} if(exists $$bistructureRef{"$bibID"}{"Author_Initials_1"});
      }elsif(exists $$bistructureRef{"$bibID"}{"Editor_FamilyName_1"}){
	$Author=$$bistructureRef{"$bibID"}{"Editor_FamilyName_1"};
	$Author=$Author . " " . $$bistructureRef{"$bibID"}{"Editor_Initials_1"} if(exists $$bistructureRef{"$bibID"}{"Editor_Initials_1"});
      }

      if ($FuzzyTitle ne ""){
	#print "FUZZZZ: \[$Author $FuzzyTitle\]\n";
	my $runFuzzyScript="java -jar -Dfile.encoding=UTF-8 \"${SCRITPATH}/bookmetrics_fuzzysearch.jar\" $Author $FuzzyTitle";
	my $ReturnText=`$runFuzzyScript`;

	($DOISource, $FuzzyDOI)=($1, $2) if ($ReturnText=~/^\s*([\w\-]+) Matched DOI: (.*)$/);

	if ($FuzzyDOI ne ""){
	  print "$bibID\n\t\t$ReturnText\n" if(defined $cline);
	  $$bistructureRef{"$bibID"}{"DOI"}=$FuzzyDOI;
	  $$bistructureRef{"$bibID"}{"DOISource"}="$DOISource";
	  $$bistructureRef{"SpringerLinkFuzzyCount"}=$$bistructureRef{"SpringerLinkFuzzyCount"} + 1;
	}else{
	  print "$bibID\t $ReturnText\n" if(defined $cline);
	}
      }
    }
  }

  return $bistructureRef;
}
#========================================================================================================================================================
sub DOI_Validation{
  my ($bistructureRef, $bistructureIDRef)=@_;
  print "DOI Validation in process...\n" if(defined $cline);
  foreach my $bibID (@$bistructureIDRef){
    if(exists $$bistructureRef{"$bibID"}{"DOI"}){
      if($$bistructureRef{"$bibID"}{"DOISource"} ne "SpringerLink"){
	#Crossref Validation
	my $DOI = $$bistructureRef{"$bibID"}{"DOI"};
	$bistructureRef=CrossRef_DoiElement_Validation($bistructureRef, $bibID, $DOI);

	if(!exists $$bistructureRef{$bibID}{"ValidationSource"}){
	  $bistructureRef=SpringerLink_DoiElement_Validation($bistructureRef, $bibID, $DOI);
	}

	#DOIORG dx.doi.org
	$bistructureRef=isDOIAvailable($bistructureRef, $bibID, $DOI);
      }
    }
  }

  return $bistructureRef;
}

#========================================================================================================================================================

sub GetSpringerMeta{

#10.1007/978-0-387-71165-2_2 
  my $doi=shift;

  my %springerMetaInfo=();
  my $springerMetaInfoRef=\%springerMetaInfo;

  my $WebContent="";
  my $urlArgument="";
  my $content_type='application/x-www-form-urlencoded';
  $doi=~s/\//\%2F/gs;
  my $url="http://content-api.springer.com/document/$doi";
  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new(GET => $url);
  $req->content_type($content_type);
  $req->content($urlArgument);
  my $res = $ua->request($req);
  my $webData=$res->content;
  my $crossRefData="";

  if ($res->is_success){

    $webData=~s/^(.*?)(<\/ArticleHeader>|<\/ChapterHeader>)(.*)$/$1$2/gs;

    $$springerMetaInfoRef{"VolumeID"}=$2 if($webData=~/<(VolumeIDStart)>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
    $$springerMetaInfoRef{"Year"}=$2 if($webData=~/<OnlineDate>\s*<(Year)>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
    $$springerMetaInfoRef{"FirstPage"}=$2 if($webData=~/<(ArticleFirstPage|ChapterFirstPage)>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
    $$springerMetaInfoRef{"ArticleTitle"}=$2 if($webData=~/<(ArticleTitle)[^<>]*?>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
    $$springerMetaInfoRef{"JournalTitle"}=$2 if($webData=~/<(JournalTitle)[^<>]*?>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
    $$springerMetaInfoRef{"BookTitle"}=$2 if($webData=~/<(BookTitle)[^<>]*?>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
    $$springerMetaInfoRef{"ChapterTitle"}=$2 if($webData=~/<(ChapterTitle)[^<>]*?>((?:(?!<[\/]?\1>).)*)<\/\1>/s);

    my $authorCount=1;
    while($webData=~s/<(Author)[^<>]*?>((?:(?!<[\/]?\1>).)*)<\/\1>//s){
      my $BibAuthorName=$2;
      $$springerMetaInfoRef{"Author_FamilyName_$authorCount"}=$2 if($BibAuthorName=~/<(FamilyName)>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
      $$springerMetaInfoRef{"Author_Initials_$authorCount"}=$2 if($BibAuthorName=~/<(GivenName)>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
      $authorCount++;
    }
    my $editorCount=1;
    while($webData=~s/<(Editor)[^<>]*>((?:(?!<[\/]?\1>).)*)<\/\1>//s){
      my $BibEditorName=$2;
      $$springerMetaInfoRef{"Editor_FamilyName_$editorCount"}=$2 if($BibEditorName=~/<(FamilyName)>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
      $$springerMetaInfoRef{"Editor_Initials_$editorCount"}=$2 if($BibEditorName=~/<(GivenName)>((?:(?!<[\/]?\1>).)*)<\/\1>/s);
      $editorCount++;
    }
  }else{
    #print $res->status_line, "\n";
    $$springerMetaInfoRef{"MetaError"}="$webData";
  }

  return $springerMetaInfoRef;
}
#===================================================================================================================================

sub checkBibType{
  my ($bistructureRef, $bibID)=@_;

  my $search_type="";
  if(exists $$bistructureRef{"$bibID"}{"JournalTitle"}){
    $search_type="journal";
    $BookJournalTitle=$$bistructureRef{"$bibID"}{"JournalTitle"};
  }elsif(exists $$bistructureRef{"$bibID"}{"BookTitle"}){
    $search_type="books";
    $BookJournalTitle=$$bistructureRef{"$bibID"}{"BookTitle"};
  }
  if(exists $$bistructureRef{"$bibID"}{"ArticleTitle"}){
    $search_type="journal";
    $articleChapterTitle=$$bistructureRef{"$bibID"}{"ArticleTitle"};
  }elsif(exists $$bistructureRef{"$bibID"}{"ChapterTitle"}){
    $search_type="books";
    $articleChapterTitle=$$bistructureRef{"$bibID"}{"ChapterTitle"};
  }

  return $search_type;
}
#===================================================================================================================================

sub SpringerLink_DoiElement_Validation{
  my ($bistructureRef, $bibID, $DOI)=@_;

  my $springerMetaInfoRef = &GetSpringerMeta($DOI);
  if(!exists $$springerMetaInfoRef{"MetaError"}){
    my $validElemnt="";
    foreach my $key (keys %$springerMetaInfoRef){
      if(exists $$bistructureRef{$bibID}{$key}){
	#if($$bistructureRef{$bibID}{$key}=~/(^|[\.\:] )\Q$$springerMetaInfoRef{$key}\E($|\: )/i){
	if($$bistructureRef{$bibID}{$key}=~/\Q$$springerMetaInfoRef{$key}\E/i){
	  if($validElemnt eq ""){
	    $validElemnt= $key;
	  }else{
	    $validElemnt= $validElemnt . "\, " . $key;
	  }
	}
      }
    }
    if ($validElemnt ne ""){
      $$bistructureRef{$bibID}{"ValidatedElements"}=$validElemnt;
      $$bistructureRef{$bibID}{"ValidationSource"}="SpringerLink";
    }
  }#IF End MetaError

  return $bistructureRef;
}
#==================================================================================================================
sub CrossRef_DoiElement_Validation{
  my ($bistructureRef, $bibID, $DOI)=@_;

  #Get Crossref DOI Meta Info
  my $crossRefMetaInfoRef = &Get_Crossref_DOI_Meta($DOI);

  if(exists $$crossRefMetaInfoRef{"status"}){
    if($$crossRefMetaInfoRef{"status"} eq "ok"){
      my %validElemntKey=();
      my $validElemnt="";
      #print %{$$bistructureRef{$bibID}}, "\n";
      foreach my $key (keys %$crossRefMetaInfoRef){
	#print "META: $key: $$crossRefMetaInfoRef{\"$key\"}\n";
	if(exists $$bistructureRef{$bibID}{$key}){
	    if(defined $$crossRefMetaInfoRef{"$key"}){  #	  if($$crossRefMetaInfoRef{"$key"} ne ""){
	      my $matchString = $$crossRefMetaInfoRef{"$key"};
	      if(exists $$bistructureRef{$bibID}{"Author_FamilyParticle_1"}){
		my $particle=$$bistructureRef{$bibID}{"Author_FamilyParticle_1"};
		${matchString}=~s/^\Q$particle\E([ ]+)//i;
	      }
	      if($$bistructureRef{$bibID}{$key}=~/\b\Q${matchString}\E/i){
		if($validElemnt eq ""){
		  $validElemnt= $key;
		  $validElemntKey{"$key"}="$key";
		}else{
		  if(!exists $validElemntKey{$key}){
		    $validElemnt= $validElemnt . "\, " . $key;
		    $validElemntKey{"$key"}="$key";
		  }
		}
	      }
	    }

	    #cross check -- if crossref have wrong title
	    if($key eq "BookTitle"){
	      if(exists $$bistructureRef{$bibID}{BookTitle}){
		if(exists $$crossRefMetaInfoRef{ChapterTitle}){
		  #if($$bistructureRef{$bibID}{BookTitle}=~/(^|[\.\:] )\Q$$crossRefMetaInfoRef{ChapterTitle}\E($|\: )/i){
		  if($$bistructureRef{$bibID}{BookTitle}=~/\Q$$crossRefMetaInfoRef{ChapterTitle}\E/i){
		    #print "$key: VALID2: $$bistructureRef{$bibID}{BookTitle}\n ";
		    if($validElemnt eq ""){
		      $validElemnt= BookTitle;
		      $validElemntKey{BookTitle}="BookTitle";
		    }else{
		      if(!exists $validElemntKey{BookTitle}){
			$validElemnt= $validElemnt . "\, " . BookTitle;
			$validElemntKey{BookTitle}="BookTitle";
		      }
		    }
		  }
		}
	      }
	    }#If End BookTitle key
	    #-------
	  }

	if($key eq "ArticleTitle"){
	  if(exists $$bistructureRef{$bibID}{ChapterTitle}){
	    if(exists $$crossRefMetaInfoRef{ArticleTitle}){
	      if($$bistructureRef{$bibID}{ChapterTitle}=~/\Q$$crossRefMetaInfoRef{ArticleTitle}\E/i){
		if($validElemnt eq ""){
		  $validElemnt= ChapterTitle;
		  $validElemntKey{ChapterTitle}="ChapterTitle";
		}else{
		  if(!exists $validElemntKey{ChapterTitle}){
		    $validElemnt= $validElemnt . "\, " . ChapterTitle;
		    $validElemntKey{ChapterTitle}="ChapterTitle";
		  }
		}
	      }
	    }# End ArticleTitle exists

	  }elsif(exists $$bistructureRef{$bibID}{BookTitle}){
	    if(exists $$crossRefMetaInfoRef{ArticleTitle}){
	      if($$bistructureRef{$bibID}{BookTitle}=~/\Q$$crossRefMetaInfoRef{ArticleTitle}\E/i){
		if($validElemnt eq ""){
		  $validElemnt= BookTitle;
		  $validElemntKey{BookTitle}="BookTitle";
		}else{
		  if(!exists $validElemntKey{BookTitle}){
		    $validElemnt= $validElemnt . "\, " . BookTitle;
		    $validElemntKey{BookTitle}="BookTitle";
		  }
		}
	      }
	    }#End ArticleTitle exists
	  } #End elsif 
	}# If End ArticleTitle

	#-------
	if($key eq "ChapterTitle"){
	  if(exists $$bistructureRef{$bibID}{BookTitle}){
	    if(exists $$crossRefMetaInfoRef{ChapterTitle}){
	      if($$bistructureRef{$bibID}{BookTitle}=~/^\Q$$crossRefMetaInfoRef{ChapterTitle}\E$/i){
		if($validElemnt eq ""){
		  $validElemnt= BookTitle;
		  $validElemntKey{BookTitle}="BookTitle";
		}else{
		  if(!exists $validElemntKey{BookTitle}){
		    $validElemnt= $validElemnt . "\, " . BookTitle;
		    $validElemntKey{BookTitle}="BookTitle";
		  }
		}
	      }elsif($$bistructureRef{$bibID}{BookTitle}=~/(^|[\.\:] )\Q$$crossRefMetaInfoRef{ChapterTitle}\E($|\: )/i){
		if($validElemnt eq ""){
		  $validElemnt= ChapterTitle;
		  $validElemntKey{ChapterTitle}="ChapterTitle";
		}else{
		  if(!exists $validElemntKey{ChapterTitle}){
		    $validElemnt= $validElemnt . "\, " . ChapterTitle;
		    $validElemntKey{ChapterTitle}="ChapterTitle";
		  }
		}
	      }
	    }#End ChapterTitle exists block
	  }#End BookTitle exists block
	}#If End ChapterTitle 
	#---------------------
      }

      if ($validElemnt ne ""){
	$$bistructureRef{$bibID}{"ValidationSource"}="CrossRef";
	if($validElemnt=~/\b(Author_FamilyName_1|Editor_FamilyName_1)\b/ and $validElemnt=~/\b(VolumeID|IssueID|FirstPage)\b/ and $validElemnt=~/\bJournalTitle\b/){
	  $$bistructureRef{$bibID}{"ValidatedElements"}=$validElemnt;
	}elsif($validElemnt=~/\b(VolumeID)\b/ and $validElemnt=~/\b(FirstPage)\b/ and $validElemnt=~/\bJournalTitle\b/){
	  $$bistructureRef{$bibID}{"ValidatedElements"}=$validElemnt;
	}elsif($validElemnt=~/\b(Author_FamilyName_1|Editor_FamilyName_1)\b/ and $validElemnt=~/\b(ArticleTitle)\b/){
	  $$bistructureRef{$bibID}{"ValidatedElements"}=$validElemnt;
	}elsif($validElemnt=~/\b(Author_FamilyName_1)\b/ and $validElemnt=~/\b(ChapterTitle)\b/){
	  $$bistructureRef{$bibID}{"ValidatedElements"}=$validElemnt;
	}elsif($validElemnt=~/\b(Author_FamilyName_1)\b/ and $validElemnt=~/\b(BookTitle)\b/ and $validElemnt=~/\b(VolumeID|Year|FirstPage|PublisherName)\b/){
	  $$bistructureRef{$bibID}{"ValidatedElements"}=$validElemnt;
	}else{
	  $$bistructureRef{$bibID}{"ValidatedElements"}=$validElemnt;
	  $$bistructureRef{$bibID}{"SuspectedDOI"}=$$bistructureRef{$bibID}{"DOI"};
	  delete $$bistructureRef{$bibID}{"DOI"};
	}

      }else{
	#--------------------Delete Non Match DOI ----------------------------
	$bistructureRef=&Delete_InvalidDOI($bistructureRef, $bibID);
	#---------------------------------------------------------------------
      }
    }
  }#IF End MetaError
  return $bistructureRef;
}

#===============================================================================================

sub Get_Crossref_DOI_Meta{
  my $doi=shift;
  #$doi='10.1007/978-0-387-71165-2_2'; #10.1002/0471721182, 10.1007/978-0-387-71165-2_2

  use JSON;

  my %crossRefMetaInfo=();
  my $crossRefMetaInfoRef=\%crossRefMetaInfo;

  my $WebContent="";
  my $urlArgument="";
  my $content_type='application/x-www-form-urlencoded';
  $doi=~s/\//\%2F/gs;
  #http://api.crossref.org/works/10.1007/s10940-007-9036-0
  my $url="http://api.crossref.org/works/$doi";
  #my $url="http://content-api.springer.com/document/$doi";

  my $ua = LWP::UserAgent->new;
  my $response = $ua->get("$url");

  my $json_text="";

  if ($response->is_success){
     $json_text=$response->decoded_content;  # or whatever
  }else{
    #die $response->status_line;
  }

#----- $json_text=> change unicode to xml ent----
  eval{
    $crossRefJson  = decode_json $json_text;
  }; warn $@ if $@;

#-----$crossRefJson=> change xml ent to unicode

    #unless($result) { print $@;}

  $$crossRefMetaInfoRef{status} = $crossRefJson->{status} if(exists $crossRefJson->{status});
    if(exists $crossRefJson->{message}->{page}){
      $$crossRefMetaInfoRef{FirstPage} = $crossRefJson->{message}->{page};
      $$crossRefMetaInfoRef{FirstPage}=~s/^([a-zA-Z0-9]+)\-([a-zA-Z0-9]+)$/$1/gs;
    }

  $$crossRefMetaInfoRef{VolumeID} = $crossRefJson->{message}->{volume} if(exists $crossRefJson->{message}->{volume});
  $$crossRefMetaInfoRef{IssueID} = $crossRefJson->{message}->{issue} if(exists $crossRefJson->{message}->{issue});
  $$crossRefMetaInfoRef{PublisherName} =  $crossRefJson->{message}->{publisher} if(exists $crossRefJson->{message}->{publisher});
  #$$crossRefMetaInfoRef{BibType} = $crossRefJson->{message}->{type} if(exists $crossRefJson->{message}->{type});
  $$crossRefMetaInfoRef{Bibtype} = $crossRefJson->{message}->{type} if(exists $crossRefJson->{message}->{type});

  if($crossRefJson->{message}->{type} eq "journal-article"){
    $$crossRefMetaInfoRef{ArticleTitle} =  $crossRefJson->{message}->{title}->[0] if(exists $crossRefJson->{message}->{title}->[0]);
    $$crossRefMetaInfoRef{JournalTitle} =  $crossRefJson->{message}->{"container-title"}->[0] if(exists $crossRefJson->{message}->{"container-title"}->[0]);
  }elsif($crossRefJson->{message}->{type} eq "proceedings-article"){
    $$crossRefMetaInfoRef{ArticleTitle} =  $crossRefJson->{message}->{title}->[0] if(exists $crossRefJson->{message}->{title}->[0]);
    $$crossRefMetaInfoRef{JournalTitle} =  $crossRefJson->{message}->{"container-title"}->[0] if(exists $crossRefJson->{message}->{"container-title"}->[0]);
  }elsif($crossRefJson->{message}->{type} eq "book-chapter"){
    $$crossRefMetaInfoRef{ChapterTitle} =  $crossRefJson->{message}->{title}->[0] if(exists $crossRefJson->{message}->{title}->[0]);
    $$crossRefMetaInfoRef{BookTitle} =  $crossRefJson->{message}->{"container-title"}->[0] if(exists $crossRefJson->{message}->{"container-title"}->[0]);
  }elsif($crossRefJson->{message}->{type} eq "book"){
    $$crossRefMetaInfoRef{ChapterTitle} =  $crossRefJson->{message}->{title}->[0] if(exists $crossRefJson->{message}->{title}->[0]);
    $$crossRefMetaInfoRef{BookTitle} =  $crossRefJson->{message}->{"container-title"}->[0] if(exists $crossRefJson->{message}->{"container-title"}->[0]);
  }else{
    $$crossRefMetaInfoRef{title} =  $crossRefJson->{message}->{title}->[0] if(exists $crossRefJson->{message}->{title}->[0]);
    $$crossRefMetaInfoRef{"container-title"} =  $crossRefJson->{message}->{"container-title"}->[0] if(exists $crossRefJson->{message}->{"container-title"}->[0]);
  }
  $$crossRefMetaInfoRef{Year} =  $crossRefJson->{message}->{issued}->{"date-parts"}->[0]->[0] if(exists $crossRefJson->{message}->{indexed}->{"date-parts"}->[0]->[0]);
  $$crossRefMetaInfoRef{"Author_FamilyName_1"} =  $crossRefJson->{message}->{author}->[0]->{family} if(exists $crossRefJson->{message}->{author}->[0]->{family});
  $$crossRefMetaInfoRef{"Author_FamilyName_2"} =  $crossRefJson->{message}->{author}->[1]->{family} if(exists $crossRefJson->{message}->{author}->[1]->{family});

  $$crossRefMetaInfoRef{ArticleTitle}=~s/([\.\,\;\:])$//gs if(exists $$crossRefMetaInfoRef{ArticleTitle});
  $$crossRefMetaInfoRef{ChapterTitle}=~s/([\.\,\;\:])$//gs if(exists $$crossRefMetaInfoRef{ChapterTitle});
  $$crossRefMetaInfoRef{BookTitle}=~s/([\.\,\;\:])$//gs  if(exists $$crossRefMetaInfoRef{BookTitle});
  $$crossRefMetaInfoRef{"Author_FamilyName_1"}=~s/([\.\,\;\:])$//gs  if(exists $$crossRefMetaInfoRef{"Author_FamilyName_1"});

  return $crossRefMetaInfoRef;
}

#=====================================================================================================================
sub Get_ResearchGate_DOI{
  my ($bistructureRef, $bibID, $searchCase)=@_;

  my ($Author, $Editor, $BookJournalTitle, $articleChapterTitle, $page, $volume, $year, $search_type)=&BibInfo($bistructureRef, $bibID);

  my $host="www.crossref.org";
  my $content_type='application/x-www-form-urlencoded';
  my $url="";
  my $urlArgument="";

    my $searchTitle="";

  if($searchCase eq "ChapterBook"){
    #$url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Author $articleChapterTitle";
    if ($Author ne ""){
      if(exists $$bistructureRef{"$bibID"}{"Author_FamilyParticle_1"}){
	$Author=$Author . " ". $$bistructureRef{"$bibID"}{"Author_FamilyParticle_1"};
      }
      if ($search_type eq "journal"){
	$url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Author $articleChapterTitle";
      }else{
	if($year ne ""){
	  $url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Author $year $articleChapterTitle";
	}else{
	  $url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Author $articleChapterTitle";
	}
      }
    #print "R GetQ1AU: $url\n";
    }else{
      if(exists $$bistructureRef{"$bibID"}{"Editor_FamilyParticle_1"}){
	$Editor=$Editor . " ". $$bistructureRef{"$bibID"}{"Editor_FamilyParticle_1"}; 
      }
      if ($search_type eq "journal"){
	$url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Editor $articleChapterTitle";
      }else{
	$url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Editor $articleChapterTitle";
      }
    #print "R Get Q1ED: $url\n";
    }
    $searchTitle=$articleChapterTitle;
  }else{
    if ($Author ne ""){
      if(exists $$bistructureRef{"$bibID"}{"Author_FamilyParticle_1"}){
	$Author=$Author . " ". $$bistructureRef{"$bibID"}{"Author_FamilyParticle_1"};
      }
      if ($search_type eq "journal"){
	$url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Author $BookJournalTitle";
      }else{
	if($year ne ""){
	  $url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Author $year $BookJournalTitle";
	}else{
	  $url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Author $BookJournalTitle";
	}
      }
    #print "R Get Q2AU: $url\n";
    }else{
      if(exists $$bistructureRef{"$bibID"}{"Editor_FamilyParticle_1"}){
	$Editor=$Editor . " ". $$bistructureRef{"$bibID"}{"Editor_FamilyParticle_1"}; 
      }
      if ($search_type eq "journal"){
	$url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Editor $BookJournalTitle";
      }else{
	if($year ne ""){
	  $url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Editor $year $BookJournalTitle";
	}else{
	  $url="http://www.researchgate.net/publicliterature.PublicLiterature.search.html?type=keyword&search-keyword=$Editor $BookJournalTitle";
	}

      }
    #print "R Get Q2ED: $url\n";
    }
    $searchTitle=$BookJournalTitle;
  }



  my $ua = LWP::UserAgent->new;
  my $DOI="";
  my $response = $ua->get($url);

# print "\n url is ===========\n";  
 # print "\n $url \n";
	
  if ($response->is_success) {

    $WebContent=$response->decoded_content;
	
 # print "\n===  WebContent ========\n"; 
 # print Dumper $WebContent;exit;

if($WebContent=~/<h5 class=\"pub-type-and-title\">\s*<span class=\"publication-type\">([^<>]+?[\:]?)<\/span>\s*<a class=\"js-publication-title-link ga-publication-item\" href=\"([^<>\"]+?)\">\s*<span class=\"publication-title js-publication-title\">([^<>]*?)\b\Q$searchTitle\E\b([^<>]*?)<\/span>\s*<\/a>\s*<\/h5>\s*<\/div>\s*<div class="authors">\s*((?:(?!<[\/]?html>)(?!<[\/]?h5>)(?!<\/div>).)*?)<a href=\"([^<>]+?)\" class=\"authors js-author-name[^<>\"]*?\">([^<>]*?)\b$Author\b([^<>]*?)<\/a>((?:(?!<[\/]?html>)(?!<[\/]?h5>)(?!<\/div>).)*?)\s*<\/div>\s*<div class="details">([^<>]+?)DOI\:([^\s<>]+?)\s*(<\/div>|<[a-z[^<>]+?>)/si){
       $DOI=$11;
       $$bistructureRef{"$bibID"}{"DOI"}=$DOI;
       $$bistructureRef{"$bibID"}{"DOISource"}="ResearchGate-Web";
       $$bistructureRef{"ResearchGateCount"}=$$bistructureRef{"ResearchGateCount"} + 1;
      print "ResearchGate-Web DOI: $DOI\n" if(defined $cline);
    }
   elsif($WebContent=~/<h5 class=\"pub-type-and-title\">\s*<span class=\"publication-type\">([^<>]+?[\:]?)<\/span>\s*<a class=\"js-publication-title-link ga-publication-item\" href=\"([^<>\"]+?)\">\s*<span class=\"publication-title js-publication-title\">([^<>]*?)\b\Q$searchTitle\E\b([^<>]*?)<\/span>\s*<\/a>\s*<\/h5>\s*<\/div>\s*<div class=\"authors\">\s*((?:(?!<[\/]?html>)(?!<[\/]?h5>)(?!<\/div>).)*?)<a href=\"([^<>]+?)\" class=\"authors js-author-name[^<>\"]*?\">([^<>]*?)\b$Author\b([^<>]*?)<\/a>((?:(?!<[\/]?html>)(?!<[\/]?h5>)(?!<\/div>).)*?)<\/div>\s*<div class=\"details\">([^<>]+?)DOI\:([^\s<>]+)\s*<span class=\"impact\">([^<>]+?)<\/span>\s*<\/div>/si){
       $DOI=$11;
       $$bistructureRef{"$bibID"}{"DOI"}=$DOI;
       $$bistructureRef{"$bibID"}{"DOISource"}="ResearchGate-Web";
       $$bistructureRef{"ResearchGateCount"}=$$bistructureRef{"ResearchGateCount"} + 1;
      print "ResearchGate-Web DOI: $DOI\n" if(defined $cline);
     }elsif($WebContent=~/<h5 class=\"pub-type-and-title\">\s*<span class=\"publication-type\">([^<>]+?[\:]?)<\/span>\s*<a class=\"js-publication-title-link ga-publication-item\" href=\"([^<>\"]+?)\">\s*<span class=\"publication-title js-publication-title\">([^<>]*?)\b\Q$searchTitle\E\b([^<>]*?)<\/span>\s*<\/a>\s*<\/h5>\s*<\/div>\s*<div class=\"authors\">\s*((?:(?!<[\/]?html>)(?!<[\/]?h5>)(?!<\/div>).)*?)<a href=\"([^<>]+?)\" class=\"authors js-author-name[^<>\"]*?\">([^<>]*?)\b$Author\b([^<>]*?)<\/a>((?:(?!<[\/]?html>)(?!<[\/]?h5>)(?!<\/div>).)*?)<\/div>\s*<div class=\"details\">([^<>]+?)DOI\:([^\s<>]+?)\s*(<\/div>|<[a-z[^<>]+?>)/si){
       $DOI=$11;
       $$bistructureRef{"$bibID"}{"DOI"}=$DOI;
       $$bistructureRef{"$bibID"}{"DOISource"}="ResearchGate-Web";
       $$bistructureRef{"ResearchGateCount"}=$$bistructureRef{"ResearchGateCount"} + 1;
      print "ResearchGate-Web DOI: $DOI\n" if(defined $cline);
     }elsif($WebContent=~/<h5 class=\"pub-type-and-title\">\s*<span class=\"publication-type\">([^<>]+?[\:]?)<\/span>\s*<a class=\"js-publication-title-link ga-publication-item\" href=\"([^<>\"]+?)\">\s*<span class=\"publication-title js-publication-title\">([^<>]*?)\b\Q$searchTitle\E\b([^<>]*?)<\/span>\s*<\/a>\s*<\/h5>\s*<\/div>\s*<div class=\"authors\">\s*((?:(?!<[\/]?html>)(?!<[\/]?h5>)(?!<\/div>).)*?)<a href=\"([^<>]+?)\" class=\"authors js-author-name[^<>\"]*?\">([^<>]*?)\b$Author\b([^<>]*?)<\/a>((?:(?!<[\/]?html>)(?!<[\/]?h5>)(?!<\/div>).)*?)<\/div>\s*/si){
      my $urlparam=$2;
      my $URL='http://www.researchgate.net/' . "$urlparam";
      $DOI=scrapPageRgate($URL);
      if ($DOI ne ""){
	$$bistructureRef{"$bibID"}{"DOI"}=$DOI;
	$$bistructureRef{"$bibID"}{"DOISource"}="ResearchGate-WebLink";
	$$bistructureRef{"ResearchGateCount"}=$$bistructureRef{"ResearchGateCount"} + 1;
	print "ResearchGate-WebLink DOI: $DOI\n" if(defined $cline);
      }
    }

  }else{
    $WebContent=$response->status_line;  # or whatever
    #die $response->status_line;
  }

  return ($bistructureRef, $DOI);
}
#======================================================================================
sub scrapPageRgate{
  my $url=shift;
  my $doi="";

  my $ua = LWP::UserAgent->new;
  my $response = $ua->get($url);
  if ($response->is_success) {
    $WebContent=$response->decoded_content;
     if($WebContent=~/<meta name=\"citation_doi\" content=\"([^<>\"]+?)\"\s*\/>/){
      $doi=$1;
    }
  }

  return $doi;
}
#==================================================================================================================================
sub readCSVFormatterIni{
  my $bistructureRef=shift;
   #chomp($SCRITPATH);
   my $csvFormatterIni="$SCRITPATH"."\/"."csvformatter\.ini";
   my ($csvFormateData, $boolValue) = &openFile($csvFormatterIni);
   if ($boolValue eq "False"){
     print "ERROR: Opening file \($csvFormatterIni\)";
     exit 3;
   }
   while($$csvFormateData=~s/\n[\s]*\#([^\n]+?)\n/\n/gs){};
  $$csvFormateData=~s/<ColumnHeader>(.*?)<\/ColumnHeader>//gs;
  $$csvFormateData=~s/\n\n+/\n/gs;
  $$csvFormateData=~s/^\#([^\n]+?)\n//gs;
   while($$csvFormateData=~ /<([A-Za-z]+)>/s)
     {
       my $logElement=$1;
       if(exists $$bistructureRef{$logElement}){
	 $$csvFormateData=~ s/<$1>/$$bistructureRef{$logElement}/s;
       }else{
	 $$csvFormateData=~ s/<([A-Za-z]+)>/<null:$1>/s;
       }
     }
  $$csvFormateData=~s/<null:([^<>]+?)>/null/gs;
  $$csvFormateData=~s/<null:/</gs;
  $$csvFormateData=~s/^([\s]+)//gs;
  $$csvFormateData=~s/([\s]+)$//gs;
  return $$csvFormateData;
}

#=====================================================================================================================
sub readCSVHeader{
   my $csvFormatterIni="$SCRITPATH"."\/"."csvformatter\.ini";
   my ($csvFormateData, $boolValue) = &openFile($csvFormatterIni);
   if ($boolValue eq "False"){print "64 = ERROR: Opening file \[$csvFormateData\]";exit 64;}
   my $columnHeader="";
   while($$csvFormateData=~s/\n[\s]*\#([^\n]+?)\n/\n/gs){};
   $$csvFormateData=~s/^\#([^\n]+?)\n//gs;
   $columnHeader=$1 if($$csvFormateData=~/<ColumnHeader>(.*?)<\/ColumnHeader>/s);
  return $columnHeader;
}

#=====================================================================================================================

sub Identify_BibPublisherName{

  my $bistructureRef=shift;
  $$bistructureRef{"SpringerRef"}=0;
  $$bistructureRef{"NonSpringerRef"}=0;

  foreach my $bibID (@$bistructureIDRef){
    my $sringerPubRef="";

    #Case 1: Find "Springer" in PublisherName element.
    if(exists $$bistructureRef{"$bibID"}{"PublisherName"}){
      if($$bistructureRef{"$bibID"}{"PublisherName"}=~/\b[sS]pringer\b/i){
	$$bistructureRef{"SpringerRef"}= $$bistructureRef{"SpringerRef"} + 1;
	$sringerPubRef = "yes";

	if(exists $$bistructureRef{"$bibID"}{"DOISource"}){
	  $$bistructureRef{"DOIObtainedForSpringerPublished"}= $$bistructureRef{"DOIObtainedForSpringerPublished"} + 1 if($$bistructureRef{"$bibID"}{"DOISource"} ne "SpringerLink");
	}
	#print "$bibID: PUB:", $$bistructureRef{"$bibID"}{"PublisherName"}, "\n" if(defined $cline);
      }
    }

    #Case 2: Check SpringerDOI. #http://content-api.springer.com/document/"DOI"
    if($sringerPubRef ne "yes"){
      if(exists $$bistructureRef{"$bibID"}{"DOI"}){
	 $sringerPubRef=&CheckSpringerDOI($$bistructureRef{"$bibID"}{"DOI"});
	if($sringerPubRef eq "yes"){
	  $$bistructureRef{"SpringerRef"}= $$bistructureRef{"SpringerRef"} + 1;
	  $$bistructureRef{"$bibID"}{"PublisherName"}="Springer";
	  #$sringerPubRef = "yes";
	if(exists $$bistructureRef{"$bibID"}{"DOISource"}){
	  $$bistructureRef{"DOIObtainedForSpringerPublished"}= $$bistructureRef{"DOIObtainedForSpringerPublished"} + 1 if($$bistructureRef{"$bibID"}{"DOISource"} ne "SpringerLink");
	}
	  #print "DOI: SP PUB: $sringerPubRef\n" if(defined $cline);
	}
      }
    }

    #Case 3: Find Springer keyword in BibUnstructured
    if($sringerPubRef ne "yes"){
      if(exists $$bistructureRef{"$bibID"}{"BibUnstructured"}){
	if($$bistructureRef{"$bibID"}{"BibUnstructured"}=~/\b[sS]pringer\b/i){
	  $$bistructureRef{"SpringerRef"}= $$bistructureRef{"SpringerRef"} + 1;
	  $$bistructureRef{"$bibID"}{"PublisherName"}="Springer";
	  $sringerPubRef = "yes";
	if(exists $$bistructureRef{"$bibID"}{"DOISource"}){
	  $$bistructureRef{"DOIObtainedForSpringerPublished"}= $$bistructureRef{"DOIObtainedForSpringerPublished"} + 1 if($$bistructureRef{"$bibID"}{"DOISource"} ne "SpringerLink");
	}
	  #print "$bibID: PUB:", $$bistructureRef{"$bibID"}{"BibUnstructured"}, "\n" if(defined $cline);
	}
      }
    }
    #Case 4: If not above case match then Non Springer
    if($sringerPubRef ne "yes"){
      $$bistructureRef{"$bibID"}{"PublisherName"}="Non Springer";
    }
  }

  $$bistructureRef{"NonSpringerRef"} = $$bistructureRef{RefCount} - $$bistructureRef{"SpringerRef"};

  return $bistructureRef;
}


#=====================================================================================================================
sub CheckSpringerDOI{
  my $doi=shift;
  my $WebContent="";
  my $urlArgument="";
  my $content_type='application/x-www-form-urlencoded';
  $doi=~s/\//\%2F/gs;
  my $url="http://content-api.springer.com/document/$doi";
  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new(GET => $url);
  $req->content_type($content_type);
  $req->content($urlArgument);
  my $res = $ua->request($req);
  #my $webData=$res->content;
  my $sringerPubRef="";
  if ($res->is_success){
    $sringerPubRef="yes";
  }else{
       #print $res->status_line, "\n";
       $$bistructureRef{"Error"}="$res->status_line";
       $sringerPubRef=$res->status_line;
     }
  return $sringerPubRef;
}

#============================================================================================================
sub XmlLog{

  my $xmlHeader='<ChapterDOI></ChapterDOI><CitedBy></CitedBy><RefCount></RefCount><SpringerRef></SpringerRef><NonSpringerRef></NonSpringerRef><BibStructuredCount></BibStructuredCount><BibUnstructuredCount></BibUnstructuredCount><SpringerLinkCount></SpringerLinkCount><DOIObtainedDirectSources></DOIObtainedDirectSources><SpringerLinkFuzzyCount></SpringerLinkFuzzyCount><SpellingMistakes></SpellingMistakes><WrongDOI></WrongDOI><ISBN></ISBN><WebLink></WebLink><DOIObtainedForSpringerPublished></DOIObtainedForSpringerPublished><DOIObtainedForNonSpringer></DOIObtainedForNonSpringer><DOIObtainedFromStructuredRef></DOIObtainedFromStructuredRef><DOIObtainedFromUnstructuredRef></DOIObtainedFromUnstructuredRef>';

   while($xmlHeader=~ /<([A-Za-z]+)><\/\1>/s)
     {
       my $logElement=$1;
       if(exists $$bistructureRef{"$logElement"}){
	 $xmlHeader=~ s/<$logElement><\/$logElement>/<$logElement>$$bistructureRef{"$logElement"}<\/$logElement>/s;
       }else{
	 $xmlHeader=~ s/<$logElement><\/$logElement>/<$logElement>NULL<\/$logElement>/s;
       }
     }

my $xmlBody='';

my $xmlBodyRow='<BibID><Bibtype></Bibtype><BibliographyText></BibliographyText><DOI></DOI><SuspectedDOI></SuspectedDOI><DOISource></DOISource><ValidatedElements></ValidatedElements><ValidationSource></ValidationSource></BibID>';

  foreach my $bibID (@$bistructureIDRef){
    if(exists $$bistructureRef{"$bibID"}{"DOI"} or exists $$bistructureRef{"$bibID"}{"SuspectedDOI"}){
      my $xmlBodyRowTemp=$xmlBodyRow;
      #$xmlBodyRowTemp=~s/<BibliographyDetails id=\"\">/<BibliographyDetails id=\"$$bistructureRef{"$bibID"}{"bibID"}\">/s;
      $xmlBodyRowTemp=~ s/<BibID>(.*?)<\/BibID>/<$$bistructureRef{"$bibID"}{"bibID"}>$1<\/$$bistructureRef{"$bibID"}{"bibID"}>/s;
      while($xmlBodyRowTemp=~ /<([A-Za-z]+)><\/\1>/s)
	{
	  my $logElement=$1;
	  if($logElement eq "BibliographyText"){
	    $$bistructureRef{"$bibID"}{"BibliographyText"}=$$bistructureRef{"$bibID"}{"BibUnstructured"};
	    while($$bistructureRef{"$bibID"}{"BibliographyText"}=~s/<span ([^<>]+?)>(.*?)<\/span>/$2/gs){};
	    while($$bistructureRef{"$bibID"}{"BibliographyText"}=~s/<(b|i|u)>(.*?)<\/\1>/$2/gs){};
	    $$bistructureRef{"$bibID"}{"BibliographyText"}=~s/<([^<>]+?)( [^<>]*?)>(.*?)<\/\1>/$3/gs;
	    $$bistructureRef{"$bibID"}{"BibliographyText"}=~s/<([^<>]+?)>(.*?)<\/\1>/$2/gs;
	  }
	  if(exists $$bistructureRef{"$bibID"}{"$logElement"}){
	    $xmlBodyRowTemp=~ s/<$logElement><\/$logElement>/<$logElement>$$bistructureRef{"$bibID"}{"$logElement"}<\/$logElement>/s;
	  }else{
	    $xmlBodyRowTemp=~ s/<$logElement><\/$logElement>/<$logElement>NULL<\/$logElement>/s;
	  }
	}
      $xmlBody="$xmlBody" . "$xmlBodyRowTemp";
    }
  }

  my $rootOpen='<?xml version="1.0" encoding="UTF-8"?><BookMetrix>';
  my $rootClose='</BookMetrix>';

  my $compliteXML="$rootOpen" . "\n<OverallStatus>$xmlHeader<\/OverallStatus>\n". "<BibliographyDetails>$xmlBody<\/BibliographyDetails>" ."$rootClose";

  return $compliteXML;
}

#=========================================================================================================================
sub isDOIAvailable{
  my ($bistructureRef, $bibID, $DOI)=@_;

 # $DOI='10.1214/aoms/21177731119'; #for testing
 # $DOI='10.1214/aoms/21177731119' if($DOI eq "10.2307/2527590");
  my $WebContent="";
  my $content_type='application/x-www-form-urlencoded';
  my $urlArgument="";
  my $url="http://dx.doi.org/$DOI";
  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new(GET => $url);
  $req->content_type($content_type);
  $req->content($urlArgument);
  my $res = $ua->request($req);
  my $webData=$res->content;
  my $title="";
  $title=$1 if($webData=~/<title>(.*?)<\/title>/s);
  if($title=~/Error: DOI Not Found/is){
    $$bistructureRef{$bibID}{"WrongDOI"}="WrongDOI";
    $$bistructureRef{"WrongDOI"}=$$bistructureRef{WrongDOI} + 1;
    $bistructureRef=&Delete_InvalidDOI($bistructureRef, $bibID);
    print "\nWRONG DOI: $DOI\n DOI removed\n";
  }
  return $bistructureRef;
}
#=========================================================================================================================
sub Delete_InvalidDOI{
  my ($bistructureRef, $bibID)=@_;

  delete $$bistructureRef{$bibID}{"DOI"};
  if($$bistructureRef{$bibID}{"DOISource"} eq "ResearchGate-Web" or $$bistructureRef{$bibID}{"DOISource"} eq "ResearchGate-WebLink"){
    $$bistructureRef{"ResearchGateCount"}=$$bistructureRef{"ResearchGateCount"} - 1;
  }
  if ($$bistructureRef{$bibID}{"DOISource"} eq "CrossRef"){
    $$bistructureRef{"CrossRefMetaCount"}=$$bistructureRef{"CrossRefMetaCount"} - 1;
  }
  if ($$bistructureRef{$bibID}{"DOISource"} eq "CrossRef-Web"){
    $$bistructureRef{"CrossRefWebCount"}=$$bistructureRef{"CrossRefWebCount"} - 1;
  }
  if ($$bistructureRef{$bibID}{"DOISource"} eq "SpringerLink-FUZZY-Search"){
    $$bistructureRef{"SpringerLinkFuzzyCountt"}=$$bistructureRef{"SpringerLinkFuzzyCountt"} - 1;
  }
  if ($$bistructureRef{$bibID}{"DOISource"} eq "Scopus"){
    $$bistructureRef{"SpringerLinkFuzzyCountt"}=$$bistructureRef{"Scopus"} - 1;
  }
  delete $$bistructureRef{$bibID}{"DOISource"};

  return $bistructureRef;
}
#=========================================================================================================================

