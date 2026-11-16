---
name: rest-resource
description: Use when designing or changing a conventional Rails CRUD resource and its HTTP contract.
family: rails
---

# Rails REST Resource

## Problem

A Rails feature needs a coherent resource route, controller action set, parameter contract, and response behavior.

## Use when

- creating a conventional CRUD resource
- converting custom endpoint paths to resource routes
- reviewing REST semantics
- adding a versioned API resource

## Do not use when

- the operation is not naturally resource-oriented
- an established domain action has a clearer command-style endpoint
- the repository deliberately uses a different protocol

## Repository inspection

Inspect routes, controller conventions, serializers/views, authentication/authorization, request tests, and existing resource naming.

## Implementation procedure

1. define the resource and supported operations
2. use resources or resource when appropriate
3. map verbs to semantics intentionally
4. keep controller actions thin and explicit
5. enforce authentication/authorization at the boundary
6. filter parameters
7. define success and error status/body contracts
8. add request-level coverage
9. inspect generated helpers and route ordering

## Example

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :articles, only: %i[index show new create edit update destroy]
end

class ArticlesController < ApplicationController
  before_action :set_article, only: %i[show edit update destroy]

  def index = @articles = Current.account.articles.order(published_at: :desc)
  def show; end
  def new = @article = Current.account.articles.build
  def edit; end

  def create
    @article = Current.account.articles.build(article_params)
    @article.save ? redirect_to(@article) : render(:new, status: :unprocessable_entity)
  end

  def update
    @article.update(article_params) ? redirect_to(@article) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @article.destroy!
    redirect_to articles_path, status: :see_other
  end

  private

  def set_article = @article = Current.account.articles.find(params[:id])
  def article_params = params.expect(article: %i[title body])
end
```

## Failure modes

- custom routes that duplicate REST resources
- wrong HTTP verbs
- authorization enforced only in the UI
- route exists but response contract is undefined
- controller action becomes a business-logic container

## Testing

Cover each supported verb/action, invalid input, authorization, not-found behavior when relevant, and response format/status.

## Review checklist

- [ ] resource name is coherent
- [ ] routes are conventional where appropriate
- [ ] verbs match operation semantics
- [ ] params are controlled
- [ ] authn/authz is enforced
- [ ] request tests cover the contract

## Related skills

- rails-routing
- rails-action-controller
- rails-authentication
- rails-architecture
- rails-test-engineering
