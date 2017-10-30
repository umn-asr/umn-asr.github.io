---
layout: post
title: "Introducing terms.umn.edu"
date: 2017-10-24
author: "Ian Whitney"
---

We are pleased to announce a new JSON API, [http://terms.umn.edu](http://terms.umn.edu). As with our other APIs this is a read-only web service that provides easy access to public data.

In this case the public data in question is, "What term is it today?" You might think this is an easy question to answer. But no! Read on to find out the surprising complexity.

<!--break-->

Because we want this service to be used by a wide range of developers we needed to ensure that we were meeting their requirements. A perfect place to do this is at the U's annual hackathon, [Campus Codefest 2017](http://umn.campuscodefest.org/events/39-campus-codefest-2017), where folks from across the University collaborate to make the U a better place.

There was a lot of interest in this project, and we quickly had a group of interested folks. And that group quickly discovered that the simple question, "What term is it today?" could be interpreted to mean two different things.

1. What term is actively occurring today?
2. What term began most recently?

What is the difference between these two questions? At the U there are gaps between terms, usually a few weeks. For example, if you're an Undergrad student at the Twin Cities, the Summer 2017 term ends on August 18th and the Fall term doesn't begin until September 5th.

So, if today is August 20th, 2017 and the Summer term ended on August 18th, what term is it today?

Fall term doesn't begin until September. So it's not Fall. But is it still Summer?

For some people the answer was "No, it is not Summer term." For these folks it mattered if today's date falls within the term. We described this as the term being _Active_ 

But, for other people the answer was "Yes, it is Summer term." For them it was Summer until Fall began. We described this as Summer being the _Latest_ term.

If our web service only knew about Active or Latest terms, then it would not work for all of the use cases on campus. And we didn't want that, so our web service knows about *both* Active and Latest terms.

If you go to [http://terms.umn.edu/active/today](http://terms.umn.edu/active/today) you'll see all _Active_ terms for all University of Minnesota campuses. These are terms that are occurring right now.

If you go to [http://terms.umn.edu/latest/today](http://terms.umn.edu/latest/today) you'll see all _Latest_ terms for all University of Minnesota campuses. This will include terms that are not active. For example, you'll see the last term ever held at the now-defunct Waseca campus

```json
{
  "id": "431394408",
  "type": "terms",
  "links": {
    "prev": "http://terms.umn.edu/terms/1615316521",
    "self": "http://terms.umn.edu/terms/431394408"
  },
  "attributes": {
    "institution": "UMNWA",
    "strm": "0998",
    "begin-date": "1999-09-06",
    "end-date": "1999-09-06",
    "name": "Qtr to Sem Cum Stats",
    "career": "UGRD"
  }
}
```

Even though it occurred in 1999 this is still the latest term to begin at Waseca.

And you're not limited to just seeing what terms are Active/Latest today. You can check any date

- [http://terms.umn.edu/active/2018-01-01](http://terms.umn.edu/active/2018-01-01)
- [http://terms.umn.edu/latest/2018-01-01](http://terms.umn.edu/latest/2018-01-01)

And you can limit your results to a single institution or academic career 

- [http://terms.umn.edu/umntc/active/2017-07-30](http://terms.umn.edu/umntc/active/2017-07-30)
- [http://terms.umn.edu/umndl/grad/active/today](http://terms.umn.edu/umndl/active/today)

Within a term you can also see what terms occurred before or after it -- within the same Institution and Career. For example, here's a Grad School term for Duluth

```json
{
"data": [
  {
    "id": "2132984107",
    "type": "terms",
    "links": {
      "prev": "http://terms.umn.edu/terms/1084393014",
      "next": "http://terms.umn.edu/terms/1920361079",
      "self": "http://terms.umn.edu/terms/2132984107"
  },
  "attributes": {
    "institution": "UMNDL",
    "strm": "1179",
    "begin-date": "2017-08-28",
    "end-date": "2017-12-15",
    "name": "Fall 2017",
    "career": "GRAD"
  }
}
```

The `prev` link will take you to the Duluth Grad School term that occurred before this one. The `next` link will take you to the Duluth Grad School that occurred after.

There's more documentation at [http://terms.umn.edu](http://terms.umn.edu). And soon we hope to have a Ruby gem that you can use as a client for this service. More to come!

Thanks to our Campus Codefest collaborators: Michael Berkowski, Jack Brown, Chris Dinger, and Timothy Traffie!
