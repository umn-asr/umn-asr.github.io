---
layout: post
title: "Testing Oracle SQL objects with utPLSQL"
subtitle:  "Part 1"
date: 2018-06-30
author: "Remy Abdullahi"
---

At ASR, we have a large number of SQL queries, functions and stored procedures for retrieving and manipulating data. One value we stand by for the software we maintain is test-driven development. Generally speaking, I feel we do a pretty good job of this. However, there is one area that had glaring holes: our large corpus of SQL objects (functions and stored procedures).

Enter utPLSQL, a unit-testing framework for Oracle PL/SQL. If you've ever worked with RSpec, it will look very familiar.

This will be a two part series. In this post, we'll go over a sample SQL function that we use at ASR. In the next, we'll go over how to use utPLSQL to write unit tests for it and nice features of utPLSQL you might find handy like reporting.

### wfg_f_convert_strm.sql

At the U, we have three terms per academic year; Spring, Summer and Fall. We store these in our databases in a scheme known as "STRM". This consists of a four-digit number, the first three of which hold the year value and the last digit representing the semester. The year value is calculated by adding 1900 to the first three characters. Semesters are as follows:

No.|Semester
--|--
3|Spring
5|Summer
9|Fall

So for example, 1179 means Fall 2017.


I found that our team was re-writing logic to make this conversion from the STRM value to a human readable value in many queries and procedures. Therefore, I decided to create a function to do this conversion for us that could be used by other SQL objects. Enter `wfg_f_convert_strm`:

```sql
CREATE OR REPLACE FUNCTION wfg_f_convert_strm
(
  p_strm IN VARCHAR2
)
  RETURN VARCHAR2
IS
BEGIN
  RETURN
      (CASE SUBSTR(p_strm, 4, 1)
        WHEN '3' THEN 'Spring'
        WHEN '5' THEN 'Summer'
        WHEN '9' THEN 'Fall'
        END)
      || ' '
      || (SUBSTR(p_strm, 1, 3) + 1900);
END wfg_f_convert_strm;
```

The goal of the function is modest. Its signature expects one STRM parameter and returns one value. But what if we wanted to write tests for this? Stay tuned for the next post.
