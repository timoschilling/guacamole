# Goals of this project

* Support building web applications with Ruby on Rails or other Rack-based frameworks
    * Support for Rails Views for example
    * Allow Rails developers to get into Guacamole as easy as possible
* Reflect the nature of NoSQL in general and ArangoDB in particular
    * Use the Datamapper pattern, because it allows us to leverage ArangoDB features like nesting in a really nice way
    * Support ArangoDB features like transactions, the query language and graphs
* Don't cut corners on quality
* Strive for simplicity

*The two main goals may conflict from time to time.*

## Design Decisions

We are well aware that the decision for data mapper in favor of active record has certain drawbacks. But this is the case with every single decision one will ever make in software development. We have strong believes in a simple software design. We think when it comes to building applications a good simple design can only be achieved by using simple libraries and frameworks. ActiveRecord is not simple anymore. And its usage will result in a not simple application. In our opinion one reason for this is the usage of the active record pattern. ActiveRecord is very convenient but it is not simple. Going with a data mapper approach is less convenient at first but will pay off in the long run.

At the same time Guacamole should enable people to use [ArangoDB](https://www.arangodb.com) in their Ruby and especially Rails projects. Due to this we will always have to compromise between our pursuit of simplicity and the usability for a wide range of developers who are mostly used to the Rails Way of doing things. We try do be more on the simple side but eventually we will fail from time to time. We don't think this is inherently a bad thing because to fail is to learn as well. We will always re-evaluate our decisions and refactor whenever possible.

## Features of Guacamole 1.0

**This is definitely a moving target and up to discussion. For non-moving targets refer to our [milestones](https://github.com/triAGENS/guacamole/issues/milestones).**

* **Embrace the Multi Model nature of ArangoDB:** It will be possible to connect entities with edges. These edges will have custom classes. It will be possible to do graph queries using these connections. There is already a [discussion about how to do this](https://github.com/triAGENS/guacamole/issues/74).
* **Support for the ArangoDB Query Language:** ArangoDB has a powerful querying language. We want to provide support for it in the most Ruby-way possible. There is already a [discussion about how to do this](https://github.com/moonglum/brazil/issues/8).
* **Support for Transactions:** ArangoDB has support for transactions, we want to make it as easy as possible to use them.
* **Support for Migrations:** Migrations work differently in a database with flexible schema. Some migrations are possible on the fly, but there will still be migrations that need to be executed explicitly. We want to support Rails-like migrations for these types of queries.
* **Support for flexible mapping:** Right now the mapping is very strict, we will allow more flexibility here including renaming or excluding certain attributes.
