using gravi_domain.Interfaces;
using gravi_infrastructure.Repositories.Base;
using gravi_infrastructure.Repositories.NpgsqlRepositories;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.UnitOfWork.RepositoryRegisters
{
    public class NpgsqlRepositoryRegistry : NpgsqlRepositoryBase, IRepositoryRegistry
    {
        private IUserRepository _user;
        private IPersonRepository _person;
        private ICountryRepository _country;

        public NpgsqlRepositoryRegistry(DbConnection connection, DbTransaction? transaction) : base(connection, transaction) { }
        public IUserRepository User => (_user ??= new UserRepository(Connection, Transaction));
        public IPersonRepository Person => (_person ??= new PersonRepository(Connection, Transaction));
        public ICountryRepository Country => (_country ??= new CountryRepository(Connection, Transaction));

    }
}
