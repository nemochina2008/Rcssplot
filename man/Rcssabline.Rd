% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcssWrappers.R
\name{Rcssabline}
\alias{Rcssabline}
\title{Add a style straight line to a plot}
\usage{
Rcssabline(a = NULL, b = NULL, h = NULL, v = NULL, reg = NULL,
  coef = NULL, Rcss = "default", Rcssclass = NULL, ...)
}
\arguments{
\item{a, b}{coefficient (intercet and slope) for line}

\item{h, v}{horizontal, vertical positions for line}

\item{reg}{an object with a coef method}

\item{coef}{vector with interect and slope for line}

\item{Rcss}{style sheet object. Leave "default" to use a style
defined via RcssSetDefaultStyle().}

\item{Rcssclass}{sub class of style sheet}

\item{...}{Further parameters, see documentation of abline()}
}
\description{
Add a style straight line to a plot
}

