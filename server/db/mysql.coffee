mysql = require('mysql')


module.exports.Mysql = class Mysql
  constructor: (@config, @max=1)->
    for i in [1..@max]
      @_connect(i)
    @

  _connect: (i)->
    @['connection' + i] = mysql.createConnection(@config)
    @['connection' + i].on 'error', (err)=>
      if not err.fatal
        return null
      if err.code isnt 'PROTOCOL_CONNECTION_LOST'
        throw err
      console.log('Re-connecting lost connection: ' + err.stack)
      @_connect(i)
    @

  query: ->
    connection_id = 1
    for i in [1..@max]
      if !@['connection' + i]._busy
        connection_id = i
        break
    connection = @['connection' + connection_id]
    connection._busy = true
    args = Array.prototype.slice.call(arguments)
    callback = args[args.length - 1]
    args[args.length - 1] = ->
      connection._busy = false
      callback.apply(@, arguments)
    connection.query.apply(connection, args)
    @

  _escape: (value)->
    @connection1.escape(value)

  _where: (where)->
    where_str = []
    for key, value of where
      where_str.push("`#{key}`=#{@_escape(value)}")
    where_str

  _parse: (parse, data, to_db = true)->
    parse.reduce (result, item)->
      Object.assign result, if item[0] of data then { [item[0]]: item[1][ if to_db then 'to' else 'from' ](data[item[0]]) }
    , Object.assign({}, data)

  select_raw: (query, data, callback)->
    # console.info query, data
    @query query, data, (err, rows)->
      if err
        console.info query, data
        throw err
      callback(rows)

  select: (data, callback)->
    fn =
      default: (field, value)->
        if value is null
          return ["s.`#{field}` IS NULL "]
        ["s.`#{field}` = ? ", value]
      sign: (field, value)-> ["s.`#{field}` #{value.sign[0]} ?", value.sign[1]]
      date: (field, value)->
        date_range = if !Array.isArray(value.date) then [ value.date ] else value.date
        return [
          date_range.map (v, i)=>
            till = i isnt 0 or ( date_range.length is 0 and v > 0 )
            "DATE(s.`#{field}`) #{if till then "<=" else ">="} DATE( ? )"
          .join ' AND '
          date_range.map (v)->
            new Date(new Date().getTime() + 1000*60*60*24 * v)
        ]
      json: (field, value)->
        ["JSON_CONTAINS(s.`#{field}`, ? )", JSON.stringify(value.json)]
      not_in: (field, value)->
        if value.not_in.length is 0
          return null
        ["s.`#{field}` NOT IN ( ? ) ", [ value.not_in ]]
      in: (field, value)->
        if value.in.length is 0
          return null
        ["s.`#{field}` IN ( ? ) ", [ value.in ]]
      array: (field, values, connect_or = true)->
        combined = values.map (value)->
          fn[fn_get(value)](field, value)
        [
          ' ( ' + combined.map( (q)-> q[0] ).join( if connect_or then ' OR ' else ' AND ' ) + ' ) '
          combined.filter( (q)-> q.length > 1 ).reduce ( (acc, q)-> acc.concat(q[1]) ), []
        ]
      or: (field, values)-> fn['array'](field, values)
      and: (field, values)-> fn['array'](field, values, false)

    fn_get = (value)->
      if value
        if Array.isArray(value)
          return 'array'
        if typeof value is 'object'
          for method in Object.keys(fn)
            if method of value
              return method
      return 'default'
    if data.where
      where = Object.keys(data.where).map (field)->
        fn[fn_get(data.where[field])](field, data.where[field])
      .filter (wh)-> !!wh
    @select_raw """
      SELECT
        #{if data.select_count then " COUNT(*) " else if data.select then data.select.map( (v)->
            if typeof v is 'object'
              mth = Object.keys(v)[0]
              return "#{mth}( s.`#{v[mth]}` )"
            "s.`#{v}`"
          ).join(', ') else 's.*'}
        #{if data.join then """,
          #{if data.join.select then data.join.select.map( (v)->
            "j.`#{v}`"
          ).join(', ') else 'j.*'}
        """ else ''}
      FROM
        `#{data.table}` AS s
      #{if data.join then """
        LEFT JOIN
          `#{data.join.table}` AS j
        ON
          #{Object.keys(data.join.on).map( (k)->
            "s.`#{k}`=j.`#{data.join.on[k]}`"
          ).join(' AND ')}
      """ else ''}
      #{if data.where then """
        WHERE
          #{where.map( (v)-> v[0] ).join(' AND ')}
      """ else ''}
      #{if data.order then """
        ORDER BY
          #{data.order.map (v)->
            if v.substr(0, 1) is '-' then "s.`#{v.substr(1)}` DESC" else "s.`#{v}` ASC"}
      """ else ''}
      #{if data.group then """
        GROUP BY
          #{data.group.map (v)->
            "s.`#{v}`" }
      """ else ''}
      LIMIT #{data.limit or '100000'}
    """, (if data.where then where.filter( (v)-> v.length > 1 ).reduce( ( (acc, v)-> acc.concat(v[1]) ), [] ) else [] ), (rows)=>
      if data.parse
        rows = rows.map (v)=> @_parse(data.parse, v, false)
      callback(rows)

  select_one: (data, callback)->
    @select Object.assign({limit: 1}, data), (rows)=>
      callback(if rows then rows[0] else null)

  select_count: (data, callback)->
    @select_one Object.assign({select_count: true}, data), (row)=>
      callback row[ Object.keys(row)[0] ]

  update: (data, callback=->)->
    Object.keys(data.data).forEach (key)->
      if data.data[key] and data.data[key].increase?
        v = data.data[key].increase
        data.data[key] = {toSqlString: -> "`#{key}` #{if v < 0 then '-' else '+'} #{Math.abs(v)}"}
    @query "UPDATE `#{data.table}` SET ? WHERE  #{@_where(data.where).join(' AND ')}", (if data.parse then @_parse(data.parse, data.data, true) else data.data), (err, result)->
      if err
        console.info data
        throw err
      callback(result)

  insert: (data, callback=->)->
    @query "INSERT INTO `#{data.table}` SET ?", (if data.parse then @_parse(data.parse, data.data, true) else data.data), (err, result)->
      if err
        console.info data
        if not data.ignore
          throw err
        else
          return
      callback(result.insertId)

  delete: (data, callback=->)->
    @query "DELETE FROM `#{data.table}` WHERE #{(@_where(data.where)).join(' AND ')}", (err, result)->
      if err
        console.info data
        throw err
      callback(result)

  replace: (data, callback=->)->
    data_insert = if data.parse then @_parse(data.parse, data.data, true) else data.data
    keys = Object.keys data_insert
    values = keys.map (k)-> data_insert[k]
    update = keys
      .filter (k)-> !(k in data.unique)
      .reduce (acc, v)->
        Object.assign acc, {[v]: data_insert[v]}
      , {}

    @query """
      INSERT INTO `#{data.table}` (#{keys.map( (k)-> "`#{k}`" ).join(', ') })
      VALUES (#{keys.map( (k)-> "?" ).join(', ') })
      ON DUPLICATE KEY UPDATE ?
    """, values.concat([update]), (err, result)->
      if err
        console.info data
        if not data.ignore
          throw err
        else
          return
      callback()
