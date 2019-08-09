module graphql.starwars.query;

import std.typecons : Nullable, nullable;
import std.format : format;
import std.experimental.logger;
import std.stdio;

import vibe.data.json;

import graphql.parser;
import graphql.builder;
import graphql.lexer;
import graphql.ast;
import graphql.graphql;
import graphql.helper;
import graphql.starwars.data;
import graphql.starwars.schema;
import graphql.starwars.types;
import graphql.validation.querybased;
import graphql.validation.schemabased;

@safe:

Json query(string s) {
	return query(s, Json.init);
}

Json query(string s, Json args) {
	auto graphqld = new GraphQLD!(StarWarsSchema);
	//auto lo = new std.experimental.logger.FileLogger("query.log");
	//graphqld.defaultResolverLog = lo;
	//graphqld.executationTraceLog = lo;

	graphqld.setResolver("queryType", "human",
			delegate(string name, Json parent, Json args,
					ref DefaultContext con) @safe
			{
				auto idPtr = "id" in args;
				Json ret = Json.emptyObject();
				if(idPtr) {
					string id = idPtr.to!string();
					Human h = getHuman(id);
					if(h is null) {
						ret["data"] = Json(null);
						return ret;
					}
					Json hj = toGraphqlJson(h);
					Json cj = toGraphqlJson(cast(Character)h);
					hj.remove("__typename");
					ret["data"] = joinJson(hj, cj);
				}
				return ret;
			}
		);

	graphqld.setResolver("queryType", "hero",
			delegate(string name, Json parent, Json args,
					ref DefaultContext con) @safe
			{
				auto e = "episode" in args;
				Json ret = Json.emptyObject();
				ret["data"] = toGraphqlJson(getHero(
						e ? nullable(cast(Episode)(*e).to!int)
							: Nullable!(Episode).init
					));
				return ret;
			}
		);

	graphqld.setResolver("Character", "friends",
			delegate(string name, Json parent, Json args,
					ref DefaultContext con) @safe
			{
				auto idPtr = "id" in parent;
				Json ret = Json.emptyObject();
				ret["data"] = Json.emptyArray();
				if(idPtr) {
					string id = idPtr.to!string();
					foreach(it; getFriends(getCharacter(id))) {
						ret["data"] ~= toGraphqlJson(it);
					}
				}
				return ret;
			}
		);

	auto l = Lexer(s);
	auto p = Parser(l);

	Document d = p.parseDocument();
	const(Document) cd = d;
	QueryValidator fv = new QueryValidator(d);
	fv.accept(cd);
	noCylces(fv.fragmentChildren);
	allFragmentsReached(fv);
	SchemaValidator!StarWarsSchema sv = new SchemaValidator!StarWarsSchema(d,
			graphqld.schema
		);
	sv.accept(cd);
	DefaultContext con;
	Json gqld = graphqld.execute(d, args, con);
	return gqld;
}

@safe unittest {
	Json rslt = query(
		`query HeroNameQuery {
			hero {
				name
			}
		}`);

	string s = `{ "data" : { "hero" : { "name" : "R2-D2" } } }`;
	Json exp = parseJson(s);
	assert(rslt == exp, rslt.toPrettyString() ~ "\n" ~ exp.toPrettyString());
}

@safe unittest {
	Json rslt = query(
		`query HeroNameQuery {
			hero {
				name
			}
		}`);
	string s = `{ "data" : { "hero" : { "name" : "R2-D2" } } }`;
	Json exp = parseJson(s);
	assert(rslt == exp, rslt.toPrettyString() ~ "\n" ~ exp.toPrettyString());
}

@safe unittest {
	Json rslt = query(
		`query HeroNameAndFriendsQuery {
			hero {
				id
				name
				friends {
					name
				}
			}
		}`);
	string s = `{
			"data": {
				"hero": {
					"id": "2001",
					"name": "R2-D2",
					"friends": [
						{
							"name": "Luke Skywalker",
						},
						{
							"name": "Han Solo",
						},
						{
							"name": "Leia Organa",
						}
					]
				}
			}
		}`;
	Json exp = parseJson(s);
	assert(rslt == exp, rslt.toPrettyString() ~ "\n" ~ exp.toPrettyString());
}

@safe unittest {
	Json rslt = query(`
		query NestedQuery {
			hero {
				name
				friends {
					name
					appearsIn
					friends {
						name
					}
				}
			}
		}`);

	string s = `
	{
		"data": {
			"hero": {
				"name": "R2-D2",
				"friends": [
					{
						"name": "Luke Skywalker",
						"appearsIn": ["NEWHOPE", "EMPIRE", "JEDI"],
						"friends": [
							{ "name": "Han Solo", },
							{ "name": "Leia Organa", },
							{ "name": "C-3PO", },
							{ "name": "R2-D2", },
						],
					},
					{
						"name": "Han Solo",
						"appearsIn": ["NEWHOPE", "EMPIRE", "JEDI"],
						"friends": [
							{ "name": "Luke Skywalker", },
							{ "name": "Leia Organa", },
							{ "name": "R2-D2", },
						],
					},
					{
						"name": "Leia Organa",
						"appearsIn": ["NEWHOPE", "EMPIRE", "JEDI"],
						"friends": [
							{ "name": "Luke Skywalker", },
							{ "name": "Han Solo", },
							{ "name": "C-3PO", },
							{ "name": "R2-D2", },
						],
					},
				],
			},
		}
	}`;
	Json exp = parseJson(s);
	assert(rslt == exp, rslt.toPrettyString() ~ "\n" ~ exp.toPrettyString());
}

@safe unittest {
	Json rslt = query(`
		query FetchLukeQuery {
			human(id: "1000") {
				name
			}
		}`);

	string s = `{ "data" : { "human" : { "name" : "Luke Skywalker" } } }`;
	Json exp = parseJson(s);
	assert(rslt == exp, format("\nexp:\n%s\ngot:\n%s",
			exp.toPrettyString(), rslt.toPrettyString()));
}

@safe unittest {
	auto args = `{"someId": "1000"}`;
	Json rslt = query(`
		query FetchSomeIDQuery($someId: String!) {
				human(id: $someId) {
					name
			}
		}`, parseJson(args));

	string s = `{ "data" : { "human" : { "name" : "Luke Skywalker" } } }`;
	Json exp = parseJson(s);
	assert(rslt == exp, format("\nexp:\n%s\ngot:\n%s",
			exp.toPrettyString(), rslt.toPrettyString()));
}

@safe unittest {
	auto args = `{"someId": "1002"}`;
	Json rslt = query(`
		query FetchSomeIDQuery($someId: String!) {
				human(id: $someId) {
					name
			}
		}`, parseJson(args));

	string s = `{ "data" : { "human" : { "name" : "Han Solo" } } }`;
	Json exp = parseJson(s);
	assert(rslt == exp, format("\nexp:\n%s\ngot:\n%s",
			exp.toPrettyString(), rslt.toPrettyString()));
}

@safe unittest {
	auto args = `{ "id" : "not a valid id" }`;
	Json rslt = query(`
		query humanQuery($id: String!) {
			human(id: $id) {
				name
			}
		}`, parseJson(args));

	string s = `{ "data" : { "human" : null } }`;
	Json exp = parseJson(s);
	assert(rslt == exp, format("\nexp:\n%s\ngot:\n%s",
			exp.toPrettyString(), rslt.toPrettyString()));
}

@safe unittest {
	Json rslt = query(`
		query FetchLukeAliased {
			luke: human(id: "1000") {
				name
			}
		}`);

	string s = `{ "data" : { "luke" : { "name" : "Luke Skywalker" } } }`;
	Json exp = parseJson(s);
	assert(rslt == exp, format("\nexp:\n%s\ngot:\n%s",
			exp.toPrettyString(), rslt.toPrettyString()));
}

@safe unittest {
	Json rslt = query(`
		query FetchLukeAndLeiaAliased {
			luke: human(id: "1000") {
				name
			}
			leia: human(id: "1003") {
				name
			}
		}`);

	string s = `{ "data" : { "luke" : { "name" : "Luke Skywalker" },
		"leia" : { "name" : "Leia Organa" } } }`;
	Json exp = parseJson(s);
	assert(rslt == exp, format("\nexp:\n%s\ngot:\n%s",
			exp.toPrettyString(), rslt.toPrettyString()));
}
