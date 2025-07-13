using gravi_domain.Interfaces;
using gravi_infrastructure.Repositories.Base;
using gravi_infrastructure.Repositories.NpgsqlRepositories;
using Microsoft.Extensions.Logging;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.UnitOfWork.RepositoryRegisters
{
    public class NpgsqlRepositoryRegistry : IRepositoryRegistry
    {
        private readonly DbConnection _connection;
        private readonly DbTransaction? _transaction;
        private readonly ILoggerFactory _loggerFactory;

        private IUserRepository _user;
        private IPersonRepository _person;
        private ICountryRepository _country;

        public NpgsqlRepositoryRegistry( DbConnection connection, DbTransaction? transaction, ILoggerFactory loggerFactory)
        { 
            _connection = connection;
            _transaction = transaction;
            _loggerFactory = loggerFactory;
        }

        public IUserRepository User => _user ??= new UserRepository(_connection, _transaction, _loggerFactory.CreateLogger<UserRepository>());

        public IPersonRepository Person => _person ??= new PersonRepository(_connection, _transaction, _loggerFactory.CreateLogger<PersonRepository>());

        public ICountryRepository Country => _country ??= new CountryRepository(_connection, _transaction, _loggerFactory.CreateLogger<CountryRepository>());
    }

}
