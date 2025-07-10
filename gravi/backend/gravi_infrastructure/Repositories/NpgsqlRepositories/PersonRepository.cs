using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using gravi_domain.Entities;
using gravi_domain.Interfaces;
using gravi_infrastructure.Repositories.Base;

namespace gravi_infrastructure.Repositories.NpgsqlRepositories
{
    public class PersonRepository : RepositoryBase, IPersonRepository
    {
        public PersonRepository(DbConnection connection, DbTransaction? transaction) : base(connection, transaction) { }



    }
}
